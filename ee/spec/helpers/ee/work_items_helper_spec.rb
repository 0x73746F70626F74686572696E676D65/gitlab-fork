# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::WorkItemsHelper, feature_category: :team_planning do
  include Devise::Test::ControllerHelpers

  describe '#work_items_show_data' do
    subject(:work_items_show_data) { helper.work_items_show_data(project) }

    before do
      stub_licensed_features(
        issuable_health_status: feature_available,
        iterations: feature_available,
        issue_weights: feature_available,
        okrs: feature_available,
        subepics: feature_available
      )
    end

    let_it_be(:project) { build(:project) }

    context 'when features are available' do
      let(:feature_available) { true }

      it 'returns true for the features' do
        expect(work_items_show_data).to include(
          {
            has_issuable_health_status_feature: "true",
            has_issue_weights_feature: "true",
            has_iterations_feature: "true",
            has_okrs_feature: "true",
            has_subepics_feature: "true"
          }
        )
      end
    end

    context 'when feature not available' do
      let(:feature_available) { false }

      it 'returns false for the features' do
        expect(work_items_show_data).to include(
          {
            has_issuable_health_status_feature: "false",
            has_issue_weights_feature: "false",
            has_iterations_feature: "false",
            has_okrs_feature: "false",
            has_subepics_feature: "false"
          }
        )
      end
    end
  end

  describe '#add_work_item_show_breadcrumb' do
    subject(:add_work_item_show_breadcrumb) { helper.add_work_item_show_breadcrumb(resource_parent, work_item.iid) }

    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Needed for querying the work item type
    let_it_be(:resource_parent) { create(:group) }

    context 'when an epic' do
      let(:work_item) { create(:work_item, :epic, namespace: resource_parent) }

      it 'adds the correct breadcrumb' do
        expect(helper).to receive(:add_to_breadcrumbs).with('Epics', group_epics_path(resource_parent))

        add_work_item_show_breadcrumb
      end
    end
    # rubocop:enable RSpec/FactoryBot/AvoidCreate
  end

  describe '#work_items_list_data' do
    let_it_be(:group) { build(:group) }

    let(:current_user) { double.as_null_object }

    subject(:work_items_list_data) { helper.work_items_list_data(group, current_user) }

    before do
      stub_licensed_features(
        epics: feature_available,
        issuable_health_status: feature_available,
        issue_weights: feature_available
      )
    end

    context 'when features are available' do
      let(:feature_available) { true }

      it 'returns true for the features' do
        expect(work_items_list_data).to include(
          {
            has_epics_feature: "true",
            has_issuable_health_status_feature: "true",
            has_issue_weights_feature: "true"
          }
        )
      end
    end

    context 'when features are not available' do
      let(:feature_available) { false }

      it 'returns false for the features' do
        expect(work_items_list_data).to include(
          {
            has_epics_feature: "false",
            has_issuable_health_status_feature: "false",
            has_issue_weights_feature: "false"
          }
        )
      end
    end
  end
end
