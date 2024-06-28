# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItem, :elastic_helpers, feature_category: :team_planning do
  let_it_be(:reusable_project) { create(:project) }

  it 'has one `color`' do
    is_expected.to have_one(:color)
      .class_name('WorkItems::Color')
      .with_foreign_key('issue_id')
      .inverse_of(:work_item)
  end

  it 'has one `synced_epic`' do
    is_expected.to have_one(:synced_epic)
      .class_name('Epic')
      .with_foreign_key('issue_id')
      .inverse_of(:work_item)
  end

  describe '#supported_quick_action_commands' do
    subject { work_item.supported_quick_action_commands }

    before do
      stub_licensed_features(issuable_health_status: true, issue_weights: true)
    end

    context 'when work item supports the health status widget' do
      let(:work_item) { build(:work_item, :objective) }

      it 'returns health status related quick action commands' do
        is_expected.to include(:health_status, :clear_health_status)
      end
    end

    context 'when work item does not the health status widget' do
      let(:work_item) { build(:work_item, :task) }

      it 'omits assignee related quick action commands' do
        is_expected.not_to include(:health_status, :clear_health_status)
      end
    end

    context 'when work item supports the weight widget' do
      let(:work_item) { build(:work_item, :task) }

      it 'returns labels related quick action commands' do
        is_expected.to include(:weight, :clear_weight)
      end
    end

    context 'when work item does not support the weight widget' do
      let(:work_item) { build(:work_item, :objective) }

      it 'omits labels related quick action commands' do
        is_expected.not_to include(:weight, :clear_weight)
      end
    end
  end

  describe '#widgets' do
    subject { build(:work_item).widgets }

    context 'for weight widget' do
      context 'when issuable weights is licensed' do
        before do
          stub_licensed_features(issue_weights: true)
        end

        it 'returns an instance of the weight widget' do
          is_expected.to include(instance_of(WorkItems::Widgets::Weight))
        end
      end

      context 'when issuable weights is unlicensed' do
        before do
          stub_licensed_features(issue_weights: false)
        end

        it 'omits an instance of the weight widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::Weight))
        end
      end
    end

    context 'for status widget', feature_category: :requirements_management do
      subject { build(:work_item, :requirement).widgets }

      context 'when requirements is licensed' do
        before do
          stub_licensed_features(requirements: true)
        end

        it 'returns an instance of the status widget' do
          is_expected.to include(instance_of(WorkItems::Widgets::Status))
        end
      end

      context 'when status is unlicensed' do
        before do
          stub_licensed_features(requirements: false)
        end

        it 'omits an instance of the status widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::Status))
        end
      end
    end

    context 'for iteration widget' do
      context 'when iterations is licensed' do
        subject { build(:work_item, *work_item_type).widgets }

        before do
          stub_licensed_features(iterations: true)
        end

        context 'when work item supports iteration' do
          where(:work_item_type) { [:task, :issue] }

          with_them do
            it 'returns an instance of the iteration widget' do
              is_expected.to include(instance_of(WorkItems::Widgets::Iteration))
            end
          end
        end

        context 'when work item does not support iteration' do
          let(:work_item_type) { :requirement }

          it 'omits an instance of the iteration widget' do
            is_expected.not_to include(instance_of(WorkItems::Widgets::Iteration))
          end
        end
      end

      context 'when iterations is unlicensed' do
        before do
          stub_licensed_features(iterations: false)
        end

        it 'omits an instance of the iteration widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::Iteration))
        end
      end
    end

    context 'for progress widget' do
      context 'when okrs is licensed' do
        subject { build(:work_item, *work_item_type).widgets }

        before do
          stub_licensed_features(okrs: true)
        end

        context 'when work item supports progress' do
          let(:work_item_type) { [:objective] }

          it 'returns an instance of the progress widget' do
            is_expected.to include(instance_of(WorkItems::Widgets::Progress))
          end
        end

        context 'when work item does not support progress' do
          let(:work_item_type) { :requirement }

          it 'omits an instance of the progress widget' do
            is_expected.not_to include(instance_of(WorkItems::Widgets::Progress))
          end
        end
      end

      context 'when okrs is unlicensed' do
        before do
          stub_licensed_features(okrs: false)
        end

        it 'omits an instance of the progress widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::Progress))
        end
      end
    end

    context 'for color widget' do
      context 'when epic color is licensed' do
        subject { build(:work_item, *work_item_type).widgets }

        before do
          stub_licensed_features(epic_colors: true)
        end

        context 'when work item supports color' do
          let(:work_item_type) { [:epic] }

          it 'returns an instance of the color widget' do
            is_expected.to include(instance_of(WorkItems::Widgets::Color))
          end
        end

        context 'when work item does not support color' do
          let(:work_item_type) { :requirement }

          it 'omits an instance of the color widget' do
            is_expected.not_to include(instance_of(WorkItems::Widgets::Color))
          end
        end
      end

      context 'when epic_colors is unlicensed' do
        before do
          stub_licensed_features(epic_colors: false)
        end

        it 'omits an instance of the color widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::Color))
        end
      end
    end

    context 'for health status widget' do
      context 'when issuable_health_status is licensed' do
        subject { build(:work_item, *work_item_type).widgets }

        before do
          stub_licensed_features(issuable_health_status: true)
        end

        context 'when work item supports health_status' do
          where(:work_item_type) { [:issue, :objective, :key_result] }

          with_them do
            it 'returns an instance of the health status widget' do
              is_expected.to include(instance_of(WorkItems::Widgets::HealthStatus))
            end
          end
        end

        context 'when work item does not support health status' do
          where(:work_item_type) { [:test_case, :requirement] }

          with_them do
            it 'omits an instance of the health status widget' do
              is_expected.not_to include(instance_of(WorkItems::Widgets::HealthStatus))
            end
          end
        end
      end

      context 'when issuable_health_status is unlicensed' do
        before do
          stub_licensed_features(issuable_health_status: false)
        end

        it 'omits an instance of the health status widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::HealthStatus))
        end
      end
    end

    context 'for legacy requirement widget', feature_category: :requirements_management do
      let(:work_item_type) { [:requirement] }

      context 'when requirements feature is licensed' do
        subject { build(:work_item, *work_item_type).widgets }

        before do
          stub_licensed_features(requirements: true)
        end

        context 'when work item supports legacy requirement' do
          it 'returns an instance of the legacy requirement widget' do
            is_expected.to include(instance_of(WorkItems::Widgets::RequirementLegacy))
          end
        end

        context 'when work item does not support legacy requirement' do
          where(:work_item_type) { [:test_case, :issue, :objective, :key_result] }

          with_them do
            it 'omits an instance of the legacy requirement widget' do
              is_expected.not_to include(instance_of(WorkItems::Widgets::RequirementLegacy))
            end
          end
        end
      end

      context 'when requirements feature is unlicensed' do
        before do
          stub_licensed_features(requirements: false)
        end

        it 'omits an instance of the legacy requirement widget' do
          is_expected.not_to include(instance_of(WorkItems::Widgets::RequirementLegacy))
        end
      end
    end
  end

  describe '#average_progress_of_children' do
    let_it_be_with_reload(:parent_work_item) { create(:work_item, :objective, project: reusable_project) }
    let_it_be_with_reload(:child_work_item1) { create(:work_item, :objective, project: reusable_project) }
    let_it_be_with_reload(:child_work_item2) { create(:work_item, :objective, project: reusable_project) }
    let_it_be_with_reload(:child_work_item3) { create(:work_item, :objective, project: reusable_project) }
    let_it_be_with_reload(:child1_progress) { create(:progress, work_item: child_work_item1, progress: 20) }
    let_it_be_with_reload(:child2_progress) { create(:progress, work_item: child_work_item2, progress: 30) }
    let_it_be_with_reload(:child3_progress) { create(:progress, work_item: child_work_item3, progress: 30) }

    context 'when workitem has zero children' do
      it 'returns 0 as average' do
        expect(parent_work_item.average_progress_of_children).to eq(0)
      end
    end

    context 'when work item has children' do
      before_all do
        create(:parent_link, work_item: child_work_item1, work_item_parent: parent_work_item)
        create(:parent_link, work_item: child_work_item2, work_item_parent: parent_work_item)
      end

      it 'returns the average of children progress' do
        expect(parent_work_item.average_progress_of_children).to eq(25)
      end

      it 'rounds the average to lower number' do
        create(:parent_link, work_item: child_work_item3, work_item_parent: parent_work_item)

        expect(parent_work_item.average_progress_of_children).to eq(26)
      end
    end
  end

  it_behaves_like 'a collection filtered by test reports state', feature_category: :requirements_management do
    let_it_be(:requirement1) { create(:work_item, :requirement) }
    let_it_be(:requirement2) { create(:work_item, :requirement) }
    let_it_be(:requirement3) { create(:work_item, :requirement) }
    let_it_be(:requirement4) { create(:work_item, :requirement) }

    before do
      create(:test_report, requirement_issue: requirement1, state: :passed)
      create(:test_report, requirement_issue: requirement1, state: :failed)
      create(:test_report, requirement_issue: requirement2, state: :failed)
      create(:test_report, requirement_issue: requirement2, state: :passed)
      create(:test_report, requirement_issue: requirement3, state: :passed)
    end
  end

  describe '#linked_work_items', feature_category: :portfolio_management do
    let_it_be(:user) { create(:user) }

    let_it_be(:authorized_project) { create(:project, :private) }
    let_it_be(:work_item) { create(:work_item, project: authorized_project) }
    let_it_be(:authorized_item_a) { create(:work_item, project: authorized_project) }
    let_it_be(:authorized_item_b) { create(:work_item, project: authorized_project) }

    let_it_be(:unauthorized_project) { create(:project, :private) }
    let_it_be(:unauthorized_item_a) { create(:work_item, project: unauthorized_project) }
    let_it_be(:unauthorized_item_b) { create(:work_item, project: unauthorized_project) }

    let_it_be(:link_a) { create(:work_item_link, source: work_item, target: authorized_item_a, link_type: 'blocks') }
    let_it_be(:link_b) { create(:work_item_link, source: authorized_item_b, target: work_item, link_type: 'blocks') }
    let_it_be(:unauthorized_link_a) do
      create(:work_item_link, source: work_item, target: unauthorized_item_a, link_type: 'blocks')
    end

    let_it_be(:unauthorized_link_b) do
      create(:work_item_link, source: unauthorized_item_b, target: work_item, link_type: 'blocks')
    end

    before_all do
      authorized_project.add_guest(user)
    end

    it 'returns only authorized linked items for given user' do
      expect(work_item.linked_work_items(user))
        .to contain_exactly(authorized_item_a, authorized_item_b)
    end

    context 'when filtering by link type' do
      it 'returns authorized items with link type `blocks`' do
        expect(work_item.linked_work_items(user, link_type: 'blocks'))
          .to contain_exactly(authorized_item_a)
      end

      it 'returns authorized items with link type `is_blocked_by`' do
        expect(work_item.linked_work_items(user, link_type: 'is_blocked_by'))
          .to contain_exactly(authorized_item_b)
      end
    end
  end

  describe '.with_reminder_frequency' do
    let(:frequency) { 'weekly' }
    let!(:weekly_reminder_work_item) { create(:work_item, project: reusable_project) }
    let!(:weekly_progress) { create(:progress, work_item: weekly_reminder_work_item, reminder_frequency: 'weekly') }
    let!(:monthly_reminder_work_item) { create(:work_item, project: reusable_project) }
    let!(:montly_progress) { create(:progress, work_item: monthly_reminder_work_item, reminder_frequency: 'monthly') }
    let!(:no_reminder_work_item) { create(:work_item, project: reusable_project) }

    subject { described_class.with_reminder_frequency(frequency) }

    it { is_expected.to contain_exactly(weekly_reminder_work_item) }
  end

  describe '.without_parent' do
    let!(:parent_work_item) { create(:work_item, :objective, project: reusable_project) }
    let!(:work_item_with_parent) { create(:work_item, :key_result, project: reusable_project) }
    let!(:parent_link) { create(:parent_link, work_item_parent: parent_work_item, work_item: work_item_with_parent) }
    let!(:work_item_without_parent) { create(:work_item, :key_result, project: reusable_project) }

    subject { described_class.without_parent }

    it { is_expected.to contain_exactly(parent_work_item, work_item_without_parent) }
  end

  describe '.with_assignees' do
    let_it_be(:user) { create(:user) }
    let_it_be(:with_assignee) { create(:work_item, project: reusable_project) }
    let_it_be(:without_assignee) { create(:work_item, :key_result, project: reusable_project) }

    before_all do
      with_assignee.assignees = [user]
    end

    subject { described_class.with_assignees }

    it { is_expected.to contain_exactly(with_assignee) }
  end

  describe '.with_descendents_of' do
    let!(:parent_work_item) { create(:work_item, :objective, project: reusable_project) }
    let!(:work_item_with_parent) { create(:work_item, :key_result, project: reusable_project) }
    let!(:parent_link) { create(:parent_link, work_item_parent: parent_work_item, work_item: work_item_with_parent) }
    let!(:work_item_without_child) { create(:work_item, :key_result, project: reusable_project) }

    subject { described_class.with_descendents_of([parent_work_item.id, work_item_without_child.id]) }

    it { is_expected.to contain_exactly(work_item_with_parent) }
  end

  describe '.with_previous_reminder_sent_before' do
    let!(:work_item_without_progress) { create(:work_item, :objective, project: reusable_project) }
    let!(:work_item_with_recent_reminder) { create(:work_item, :objective, project: reusable_project) }
    let!(:work_item_with_stale_reminder) { create(:work_item, :objective, project: reusable_project) }
    let!(:recent_reminder) do
      create(:progress, work_item: work_item_with_recent_reminder, last_reminder_sent_at: 1.day.ago)
    end

    let!(:stale_reminder) do
      create(:progress, work_item: work_item_with_stale_reminder, last_reminder_sent_at: 3.days.ago)
    end

    subject { described_class.with_previous_reminder_sent_before(2.days.ago) }

    it { is_expected.to contain_exactly(work_item_without_progress, work_item_with_stale_reminder) }
  end

  describe 'versioned descriptions' do
    it_behaves_like 'versioned description'

    context 'when it is a work item of type epic' do
      let(:type) { create(:work_item_type, :epic) }
      let(:work_item) do
        create(:work_item, description: 'Original description', work_item_type: type, project: reusable_project)
      end

      it 'creates a versioned description on epic work item' do
        expect { work_item.update!(description: 'Another description') }
          .to change { work_item.own_description_versions.count }
      end

      context 'when set to skip description version' do
        it 'does not create a versioned description on epic work item' do
          expect { work_item.update!(description: 'Another description', skip_description_version: true) }
            .not_to change { work_item.own_description_versions.count }
        end
      end
    end
  end

  describe '#ensure_metrics!' do
    subject(:create_work_item) { create(:work_item, project: reusable_project, work_item_type: type) }

    context 'when it is not a work item of type epic' do
      let(:type) { create(:work_item_type, :issue) }

      it 'creates metrics after saving' do
        expect(create_work_item).to be_persisted

        expect(Issue::Metrics.count).to eq(1)
      end
    end

    context 'when it is a work item of type epic' do
      let(:type) { create(:work_item_type, :epic) }

      it 'does not create metrics after saving' do
        expect(create_work_item).to be_persisted

        expect(Issue::Metrics.count).to eq(0)
      end
    end
  end

  describe '#allowed_work_item_type_change' do
    context 'when epic work item does not have a synced legacy epic' do
      let(:work_item) { create(:work_item, :epic) }

      it 'is does change work item type from epic to issue' do
        work_item.assign_attributes(work_item_type: WorkItems::Type.default_by_type(:issue))

        expect(work_item).to be_valid
        expect(work_item.errors[:work_item_type_id]).to be_empty
      end
    end

    context 'when epic work item has a synced legacy epic' do
      let!(:epic) { create(:epic, :with_synced_work_item) }
      let(:work_item) { epic.work_item }

      it 'is does not change work item type from epic to issue' do
        work_item.assign_attributes(work_item_type: WorkItems::Type.default_by_type(:issue))

        expect(work_item).not_to be_valid
        expect(work_item.errors[:work_item_type_id])
          .to include(_('cannot be changed to issue when the work item is a legacy epic synced work item'))
      end
    end
  end

  describe '#use_elasticsearch?' do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:work_item) { create(:work_item, namespace: namespace) }

    context 'when elastic_index_work_items is disabled' do
      before do
        stub_feature_flags(elastic_index_work_items: false)
      end

      it 'returns false' do
        expect(work_item.use_elasticsearch?).to be_falsey
      end
    end

    context 'when migration is not complete' do
      before do
        set_elasticsearch_migration_to :create_work_items_index, including: false
      end

      it 'returns false' do
        expect(work_item.use_elasticsearch?).to be_falsey
      end
    end

    context 'when namespace does not use elasticsearch' do
      it 'returns false' do
        stub_feature_flags(elastic_index_work_items: false)
        set_elasticsearch_migration_to :create_work_items_index, including: true
        stub_ee_application_setting(elasticsearch_indexing: true, elasticsearch_limit_indexing: true)

        expect(work_item.use_elasticsearch?).to be_falsey
      end
    end

    context 'when work_item index is available and namesapce uses elasticsearch' do
      before do
        set_elasticsearch_migration_to :create_work_items_index, including: true
        stub_ee_application_setting(elasticsearch_indexing: true, elasticsearch_limit_indexing: false)
      end

      it 'returns true' do
        expect(work_item.use_elasticsearch?).to be_truthy
      end
    end
  end

  describe '#preload_for_indexing' do
    let_it_be(:work_item) { create(:work_item) }

    it 'preloads for indexing  and avoid N+1 queries' do
      work_item = described_class.preload_for_indexing.first
      recorder = ActiveRecord::QueryRecorder.new do
        work_item.namespace
        work_item.labels
        work_item.project.project_feature
      end
      expect(recorder.count).to be_zero
    end
  end

  describe '#elastic_reference' do
    let(:work_item) { create(:work_item) }

    it 'returns the string representation for the elasticsearch' do
      expect(work_item.elastic_reference).to eq("WorkItem|#{work_item.id}|#{work_item.es_parent}")
    end
  end

  describe '#es_parent' do
    let(:namespace) { create(:namespace) }
    let(:work_item) { create(:work_item, namespace: namespace) }

    it 'returns to correct routing id' do
      expect(work_item.es_parent).to eq("group_#{namespace.root_ancestor.id}")
    end
  end

  context 'when deleting a work item' do
    context 'and associated legacy epic has award emojis' do
      let_it_be_with_reload(:work_item) { create(:work_item, :epic_with_legacy_epic) }
      let_it_be_with_reload(:epic) { work_item.sync_object }
      let_it_be(:emoji_1) { create(:award_emoji, awardable: work_item) }
      let_it_be(:emoji_2) { create(:award_emoji, awardable: epic) }
      let_it_be(:emoji_3) { create(:award_emoji, awardable: epic) }
      let_it_be(:emoji_4) { create(:award_emoji) } # Not to be deleted

      it 'also deletes award emoji from legacy epic' do
        expect { work_item.destroy! }.to change { ::AwardEmoji.count }.by(-3)
        expect(emoji_4.reload).to be_persisted
      end
    end
  end
end
