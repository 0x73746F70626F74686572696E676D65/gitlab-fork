# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::GroupPolicy, feature_category: :remote_development do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:admin_in_non_admin_mode) { create(:admin) }
  let_it_be(:admin_in_admin_mode) { create(:admin) }
  let_it_be(:owner) { create(:user, owner_of: [group]) }
  let_it_be(:maintainer) { create(:user, maintainer_of: [group]) }
  let_it_be(:developer) { create(:user, developer_of: [group]) }
  let_it_be(:reporter) { create(:user, reporter_of: [group]) }
  let_it_be(:guest) { create(:user, guest_of: [group]) }

  describe ':admin_remote_development_cluster_agent_mapping' do
    let(:ability) { :admin_remote_development_cluster_agent_mapping }

    where(:policy_class, :user, :result) do
      # In the future, there is a possibility that a common policy module may have to be mixed in to multiple
      # target policy types for ex. ProjectNamespacePolicy or UserNamespacePolicy. As a result, the policy_class
      # has been parameterized to accommodate different values that may exist in the future
      #
      # See the following issues for more details:
      #   - https://gitlab.com/gitlab-org/gitlab/-/issues/417894
      #   - https://gitlab.com/gitlab-org/gitlab/-/issues/454934#note_1867678918
      GroupPolicy | ref(:guest)                   | false
      GroupPolicy | ref(:reporter)                | false
      GroupPolicy | ref(:developer)               | false
      GroupPolicy | ref(:maintainer)              | false
      GroupPolicy | ref(:owner)                   | true
      GroupPolicy | ref(:admin_in_admin_mode)     | true
      GroupPolicy | ref(:admin_in_non_admin_mode) | false
    end

    with_them do
      subject(:policy) { policy_class.new(user, group) }

      before do
        enable_admin_mode!(admin_in_admin_mode) if user == admin_in_admin_mode

        debug = false # Set to true to enable debugging of policies, but change back to false before committing
        debug_policies(user, group, policy_class, ability) if debug
      end

      it { expect(policy.allowed?(ability)).to eq(result) }
    end
  end

  describe ':read_remote_development_cluster_agent_mapping' do
    let(:ability) { :read_remote_development_cluster_agent_mapping }

    where(:policy_class, :user, :result) do
      # In the future, there is a possibility that a common policy module may have to be mixed in to multiple
      # target policy types for ex. ProjectNamespacePolicy or UserNamespacePolicy. As a result, the policy_class
      # has been parameterized to accommodate different values that may exist in the future
      #
      # See the following issues for more details:
      #   - https://gitlab.com/gitlab-org/gitlab/-/issues/417894
      #   - https://gitlab.com/gitlab-org/gitlab/-/issues/454934#note_1867678918
      GroupPolicy | ref(:guest)                   | false
      GroupPolicy | ref(:reporter)                | false
      GroupPolicy | ref(:developer)               | false
      GroupPolicy | ref(:maintainer)              | true
      GroupPolicy | ref(:owner)                   | true
      GroupPolicy | ref(:admin_in_admin_mode)     | true
      GroupPolicy | ref(:admin_in_non_admin_mode) | false
    end

    with_them do
      subject(:policy) { policy_class.new(user, group) }

      before do
        enable_admin_mode!(admin_in_admin_mode) if user == admin_in_admin_mode

        debug = false # Set to true to enable debugging of policies, but change back to false before committing
        debug_policies(user, group, policy_class, ability) if debug
      end

      it { expect(policy.allowed?(ability)).to eq(result) }
    end
  end

  # NOTE: Leaving this method here for future use. You can also set GITLAB_DEBUG_POLICIES=1. For more details, see:
  #       https://docs.gitlab.com/ee/development/permissions/custom_roles.html#refactoring-abilities
  # This may be generalized in the future for use across all policy specs
  # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/463453
  def debug_policies(user, group, policy_class, ability)
    puts "\n\nPolicy debug for #{policy_class} policy:\n"
    puts "user: #{user.username} (id: #{user.id}, admin: #{user.admin?}, " \
      "admin_mode: #{user && Gitlab::Auth::CurrentUserMode.new(user).admin_mode?}" \
      ")\n"
    puts "group: #{group.name} (id: #{group.id}, " \
      "owners: #{group.owners.to_a}" \
      "max_member_access_for_user(user) (from lib/gitlab/access.rb): #{group.max_member_access_for_user(user)}" \
      ")\n"

    policy = policy_class.new(user, group)
    puts "debugging :#{ability} ability:\n\n"
    pp policy.debug(ability)
    puts "\n\n"
  end
end
