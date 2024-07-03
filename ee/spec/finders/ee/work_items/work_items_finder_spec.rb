# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::WorkItemsFinder, feature_category: :team_planning do
  context 'when filtering work items' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    subject do
      described_class.new(user, params).execute
    end

    context 'with status widget' do
      let_it_be(:work_item1) { create(:work_item, project: project) }
      let_it_be(:work_item2) { create(:work_item, :satisfied_status, project: project) }

      let(:params) { { status_widget: { status: 'passed' } } }

      before do
        project.add_reporter(user)
      end

      it 'returns correct results' do
        is_expected.to match_array([work_item2])
      end
    end

    context 'with legacy requirement widget' do
      let_it_be(:work_item1) { create(:work_item, project: project) }
      let_it_be(:work_item2) { create(:work_item, :satisfied_status, project: project) }

      let(:params) { { requirement_legacy_widget: { legacy_iids: work_item2.requirement.iid } } }

      before do
        project.add_reporter(user)
      end

      it 'returns correct results' do
        is_expected.to match_array([work_item2])
      end
    end

    context 'when epic labels are split across epic and epic work item' do
      let_it_be(:label1) { create(:group_label, group: group) }
      let_it_be(:label2) { create(:group_label, group: group) }
      let_it_be(:label3) { create(:group_label, group: group) }
      let_it_be(:label4) { create(:group_label, group: group) }
      let_it_be(:label5) { create(:group_label, group: group) }
      let_it_be(:work_item1) { create(:work_item, :epic, namespace: group, title: 'group work item1') }
      let_it_be(:labeled_epic1) { create(:labeled_epic, group: group, title: 'labeled epic', labels: [label1, label2]) }
      let_it_be(:labeled_epic2) { create(:labeled_epic, group: group, title: 'labeled epic2', labels: [label4]) }
      let_it_be(:unlabeled_epic3) { create(:epic, group: group, title: 'labeled epic3') }
      let_it_be(:epic_work_item1) { labeled_epic1.work_item }
      let_it_be(:epic_work_item2) { labeled_epic2.work_item }
      let_it_be(:epic_work_item3) { unlabeled_epic3.work_item }

      let(:filtering_params) { {} }
      let(:params) { filtering_params.merge(group_id: group) }

      before do
        group.add_reporter(user)

        epic_work_item1.labels << label3
        epic_work_item2.labels << label5
      end

      context 'when epic_and_work_item_labels_unification FF is enabled' do
        context 'when searching by NONE' do
          let(:filtering_params) { { label_name: ['None'] } }

          it 'returns correct epic work items' do
            # these epic work items have no labels neither on epic or epic work item side, e.g.
            is_expected.to contain_exactly(work_item1, epic_work_item3)
          end
        end

        context 'with `and` search' do
          context 'when searching by label assigned only to epic' do
            let(:filtering_params) { { label_name: [label2.title] } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(epic_work_item1)
            end
          end

          context 'when searching by a combination of labels assigned to epic and epic work item' do
            let(:filtering_params) { { label_name: [label3.title, label1.title] } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(epic_work_item1)
            end
          end
        end

        context 'with `or` search' do
          context 'when searching by label assigned only to epic' do
            let(:filtering_params) { { or: { label_name: [label1.title, label4.title] } } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(epic_work_item1, epic_work_item2)
            end
          end

          context 'when searching by a combination of labels assigned to epic and epic work item' do
            let(:filtering_params) { { or: { label_name: [label1.title, label5.title] } } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(epic_work_item1, epic_work_item2)
            end
          end
        end

        context 'with `not` search' do
          context 'when searching by label assigned only to epic' do
            let(:filtering_params) { { not: { label_name: [label1.title, label4.title] } } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(*(group.work_items.to_a - [epic_work_item1, epic_work_item2]))
            end
          end

          context 'when searching by a combination of labels assigned to epic and epic work item' do
            let(:filtering_params) { { not: { label_name: [label1.title, label5.title] } } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(*(group.work_items.to_a - [epic_work_item1, epic_work_item2]))
            end
          end
        end
      end

      context 'when epic_and_work_item_labels_unification FF is disabled' do
        before do
          stub_feature_flags(epic_and_work_item_labels_unification: false)
        end

        context 'when searching by NONE' do
          let(:filtering_params) { { label_name: ['None'] } }

          it 'returns correct epics' do
            is_expected.to contain_exactly(work_item1, epic_work_item3)
          end
        end

        context 'with `and` search' do
          context 'when searching by label assigned only to epic' do
            let(:filtering_params) { { label_name: [label2.title] } }

            it 'returns correct epics' do
              is_expected.to be_empty
            end
          end

          context 'when searching by a combination of labels assigned to epic and epic work item' do
            let(:filtering_params) { { label_name: [label3.title, label1.title] } }

            it 'returns correct epics' do
              is_expected.to be_empty
            end
          end
        end

        context 'with `or` search' do
          context 'when searching by label assigned only to epic' do
            let(:filtering_params) { { or: { label_name: [label1.title, label4.title] } } }

            it 'returns correct epics' do
              # because we search by labels that are assigned just to epic work item, we get no result
              is_expected.to be_empty
            end
          end

          context 'when searching by a combination of labels assigned to epic and epic work item' do
            let(:filtering_params) { { or: { label_name: [label1.title, label5.title] } } }

            it 'returns correct epics' do
              # because the label4 is assigned to the epic we get that epic as a result
              is_expected.to contain_exactly(epic_work_item2)
            end
          end
        end

        context 'with `not` search' do
          context 'when searching by label assigned only to epic' do
            let(:filtering_params) { { not: { label_name: [label1.title, label4.title] } } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(*group.work_items)
            end
          end

          context 'when searching by a combination of labels assigned to epic and epic work item' do
            let(:filtering_params) { { not: { label_name: [label1.title, label5.title] } } }

            it 'returns correct epics' do
              is_expected.to contain_exactly(*(group.work_items - [epic_work_item2]))
            end
          end
        end
      end
    end

    context 'when emojis are present on its associated legacy epic' do
      let_it_be(:object1) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be(:object2) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be(:object3) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be(:object4) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

      it_behaves_like 'filter by unified emoji association'
    end
  end
end
