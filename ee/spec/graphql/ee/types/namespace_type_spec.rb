# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Namespace'], feature_category: :groups_and_projects do
  it 'has specific fields' do
    expected_fields = %w[
      add_on_eligible_users
      add_on_purchase
      additional_purchased_storage_size
      total_repository_size_excess
      total_repository_size
      contains_locked_projects
      repository_size_excess_project_count
      actual_repository_size_limit
      actual_size_limit
      storage_size_limit
      compliance_frameworks
      pipeline_execution_policies
      scan_execution_policies
      approval_policies
      security_policy_project
      product_analytics_stored_events_limit
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'Customized fields' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, additional_purchased_storage_size: 100, repository_size_limit: 10_240) }
    let_it_be(:group_member) { create(:group_member, group: group, user: user) }
    let_it_be(:query) do
      %(
        query {
          namespace(fullPath: "#{group.full_path}") {
            additionalPurchasedStorageSize
            containsLockedProjects
            actualRepositorySizeLimit
          }
        }
      )
    end

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    it "returns the expected values for customized fields defined in NamespaceType" do
      namespace = subject.dig('data', 'namespace')

      expect(namespace['additionalPurchasedStorageSize']).to eq(100.megabytes)
      expect(namespace['containsLockedProjects']).to eq(false)
      expect(namespace['actualRepositorySizeLimit']).to eq(10_240)
    end
  end
end
