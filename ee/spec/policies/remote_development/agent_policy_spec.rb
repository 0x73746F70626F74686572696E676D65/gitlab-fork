# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::AgentPolicy, feature_category: :remote_development do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be(:agent) { create(:ee_cluster_agent) }
  let_it_be(:project) { agent.project }
  let_it_be(:admin_in_non_admin_mode) { create(:admin) }
  let_it_be(:admin_in_admin_mode) { create(:admin) }
  let_it_be(:owner) { create(:user, owner_of: [project]) }
  let_it_be(:maintainer) { create(:user, maintainer_of: [project]) }
  let_it_be(:developer) { create(:user, developer_of: [project]) }
  let_it_be(:reporter) { create(:user, reporter_of: [project]) }
  let_it_be(:guest) { create(:user, guest_of: [project]) }

  describe ':admin_remote_development_cluster_agent_mapping' do
    let(:ability) { :admin_remote_development_cluster_agent_mapping }

    where(:user, :result) do
      ref(:guest)                   | false
      ref(:reporter)                | false
      ref(:developer)               | false
      ref(:maintainer)              | false
      ref(:owner)                   | true
      ref(:admin_in_non_admin_mode) | false
      ref(:admin_in_admin_mode)     | true
    end

    with_them do
      subject(:policy) { Clusters::AgentPolicy.new(user, agent) }

      before do
        enable_admin_mode!(admin_in_admin_mode) if user == admin_in_admin_mode

        debug = false # Set to true to enable debugging of policies, but change back to false before committing
        debug_policies(user, agent, Clusters::AgentPolicy, ability) if debug
      end

      it { expect(policy.allowed?(ability)).to eq(result) }
    end
  end

  describe ':read_remote_development_cluster_agent_mapping' do
    let(:ability) { :read_remote_development_cluster_agent_mapping }

    where(:user, :result) do
      ref(:guest)                   | false
      ref(:reporter)                | false
      ref(:developer)               | false
      ref(:maintainer)              | true
      ref(:owner)                   | true
      ref(:admin_in_non_admin_mode) | false
      ref(:admin_in_admin_mode)     | true
    end

    with_them do
      subject(:policy) { Clusters::AgentPolicy.new(user, agent) }

      before do
        enable_admin_mode!(admin_in_admin_mode) if user == admin_in_admin_mode

        debug = false # Set to true to enable debugging of policies, but change back to false before committing
        debug_policies(user, agent, Clusters::AgentPolicy, ability) if debug
      end

      it { expect(policy.allowed?(ability)).to eq(result) }
    end
  end

  # NOTE: Leaving this method here for future use. You can also set GITLAB_DEBUG_POLICIES=1. For more details, see:
  #       https://docs.gitlab.com/ee/development/permissions/custom_roles.html#refactoring-abilities
  # This may be generalized in the future for use across all policy specs
  # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/463453
  def debug_policies(user, agent, policy_class, ability)
    puts "\n\nPolicy debug for #{policy_class} policy:\n"
    puts "user: #{user.username} (id: #{user.id}, admin: #{user.admin?}, " \
      "admin_mode: #{user && Gitlab::Auth::CurrentUserMode.new(user).admin_mode?}, " \
      "agent.project.owners: #{agent.project.owners.to_a}, " \
      "agent.project.maintainers: #{agent.project.maintainers.to_a}" \
      ")\n"

    policy = policy_class.new(user, agent)
    puts "debugging :#{ability} ability:\n\n"
    pp policy.debug(ability)
    puts "\n\n"
  end
end
