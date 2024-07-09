# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::UserDiscussionsCountResolver, feature_category: :team_planning do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :repository, :public) }
    let_it_be(:private_project) { create(:project, :repository, :private) }

    specify do
      expect(described_class).to have_nullable_graphql_type(GraphQL::Types::Int)
    end

    context 'when counting discussions from an epic' do
      let_it_be(:epic) { create(:epic) }
      let_it_be(:private_epic) { create(:epic, group: create(:group, :private)) }
      let_it_be(:public_discussions) { create_list(:discussion_note, 2, noteable: epic) }
      let_it_be(:system_note) { create(:discussion_note, system: true, noteable: epic) }
      let_it_be(:private_discussions) { create_list(:discussion_note, 3, noteable: private_epic) }

      before do
        stub_licensed_features(epics: true)
      end

      context 'when counting discussions from a public epic' do
        subject { batch_sync { resolve_user_discussions_count(epic) } }

        it 'returns the number of non-system discussions for the epic' do
          expect(subject).to eq(2)
        end
      end

      context 'when a user does not have permission to view discussions' do
        subject { batch_sync { resolve_user_discussions_count(private_epic) } }

        it 'generates an error' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
            subject
          end
        end
      end

      context 'when a user has permission to view notes' do
        before do
          private_epic.group.add_developer(user)
        end

        subject { batch_sync { resolve_user_discussions_count(private_epic) } }

        it 'returns the number of discussions for the issue' do
          expect(subject).to eq(3)
        end

        context 'when notes are also added to epic work item side' do
          let_it_be(:work_item) { private_epic.sync_object }

          it 'returns the number of discussions for the issue' do
            # 3 user notes from epic, 5 user notes from epic work item
            first_discussion_note = create(:discussion_note_on_issue, noteable: work_item)
            create_list(:note, 2, noteable: work_item, discussion_id: first_discussion_note.discussion_id)
            second_discussion_note = create(:discussion_note_on_issue, noteable: work_item)
            create_list(:note, 3, noteable: work_item, discussion_id: second_discussion_note.discussion_id)

            # 3 discussions from legacy epic and 2 discussions from epic work item
            expect(subject).to eq(3 + 2)
          end

          context 'when epic_and_work_item_notes_unification FF is disabled' do
            before do
              stub_feature_flags(epic_and_work_item_notes_unification: false)
            end

            it 'returns the number of notes for the issue' do
              # 3 user notes from epic, 5 user notes from epic work item
              expect(subject).to eq(3)
            end
          end
        end
      end
    end
  end

  def resolve_user_discussions_count(obj)
    resolve(described_class, obj: obj, ctx: { current_user: user })
  end
end
