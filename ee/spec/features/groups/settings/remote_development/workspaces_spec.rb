# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group Workspaces Settings', :js, feature_category: :remote_development do
  include WaitForRequests

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) do
    create(:project, :public, :in_group, :custom_repo, path: 'test-project', namespace: group)
  end

  let_it_be(:agent) do
    create(:ee_cluster_agent, :with_remote_development_agent_config, project: project, created_by_user: user)
  end

  before_all do
    group.add_developer(user)
  end

  before do
    stub_licensed_features(remote_development: true)
    stub_feature_flags(remote_development_namespace_agent_authorization: true)

    sign_in(user)
    visit group_settings_workspaces_path(group)
    wait_for_requests
  end

  describe 'Group agents' do
    context 'when there are not available agents' do
      it 'displays available agents table with empty state message' do
        expect(page).to have_content 'This group has no available agents.'
      end
    end

    context 'when there are available agents' do
      let_it_be(:cluster_agent_mapping) do
        create(
          :remote_development_namespace_cluster_agent_mapping,
          user: user, agent: agent,
          namespace: group
        )
      end

      it 'displays agent in the agents table' do
        expect(page).to have_content agent.name
      end
    end
  end
end
