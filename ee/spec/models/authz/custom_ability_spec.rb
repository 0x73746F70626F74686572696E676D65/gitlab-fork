# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::CustomAbility, feature_category: :system_access do
  describe '.allowed?', :request_store do
    using RSpec::Parameterized::TableSyntax

    subject(:custom_ability) { described_class }

    let_it_be_with_reload(:user) { create(:user) }
    let_it_be(:root_group) { create(:group) }
    let_it_be(:group) { create(:group, parent: root_group) }
    let_it_be(:child_group) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:child_project) { create(:project, group: child_group) }
    let_it_be(:project_runner) { create(:ci_runner, :project, projects: [project]) }
    let_it_be(:group_runner) { create(:ci_runner, :group, groups: [group]) }

    where(:source, :ability, :resource, :expected) do
      Gitlab::CustomRoles::Definition.all.each do |(name, attrs)| # rubocop:disable Rails/FindEach -- this is not a rails model
        nil | name | ref(:root_group) | false
        nil | name | ref(:group) | false
        nil | name | ref(:child_group) | false
        nil | name | ref(:project) | false
        nil | name | ref(:child_project) | false
        nil | name | ref(:group_runner) | false
        nil | name | ref(:project_runner) | false
        nil | name | "unknown" | false

        ref(:root_group) | name | ref(:root_group) | attrs[:group_ability]
        ref(:root_group) | name | ref(:group) | attrs[:group_ability]
        ref(:root_group) | name | ref(:child_group) | attrs[:group_ability]
        ref(:root_group) | name | ref(:project) | attrs[:project_ability]
        ref(:root_group) | name | ref(:child_project) | attrs[:project_ability]
        ref(:root_group) | name | ref(:group_runner) | attrs[:group_ability]
        ref(:root_group) | name | ref(:project_runner) | attrs[:project_ability]
        ref(:root_group) | name | "unknown" | false

        ref(:group) | name | ref(:root_group) | false
        ref(:group) | name | ref(:group) | attrs[:group_ability]
        ref(:group) | name | ref(:child_group) | attrs[:group_ability]
        ref(:group) | name | ref(:project) | attrs[:project_ability]
        ref(:group) | name | ref(:child_project) | attrs[:project_ability]
        ref(:group) | name | ref(:group_runner) | attrs[:group_ability]
        ref(:group) | name | ref(:project_runner) | attrs[:project_ability]
        ref(:group) | name | "unknown" | false

        ref(:child_group) | name | ref(:root_group) | false
        ref(:child_group) | name | ref(:group) | false
        ref(:child_group) | name | ref(:child_group) | attrs[:group_ability]
        ref(:child_group) | name | ref(:project) | false
        ref(:child_group) | name | ref(:child_project) | attrs[:project_ability]
        ref(:child_group) | name | ref(:group_runner) | false
        ref(:child_group) | name | ref(:project_runner) | false
        ref(:child_group) | name | "unknown" | false

        ref(:project) | name | ref(:root_group) | false
        ref(:project) | name | ref(:group) | false
        ref(:project) | name | ref(:child_group) | false
        ref(:project) | name | ref(:project) | attrs[:project_ability]
        ref(:project) | name | ref(:child_project) | false
        ref(:project) | name | ref(:group_runner) | false
        ref(:project) | name | ref(:project_runner) | attrs[:project_ability]
        ref(:project) | name | "unknown" | false

        ref(:child_project) | name | ref(:root_group) | false
        ref(:child_project) | name | ref(:group) | false
        ref(:child_project) | name | ref(:child_group) | false
        ref(:child_project) | name | ref(:project) | false
        ref(:child_project) | name | ref(:child_project) | attrs[:project_ability]
        ref(:child_project) | name | ref(:group_runner) | false
        ref(:child_project) | name | ref(:project_runner) | false
        ref(:child_project) | name | "unknown" | false
      end

      nil | nil | nil | false
    end

    with_them do
      let!(:role) { create(:member_role, :guest, ability, namespace: root_group) if ability }
      let!(:membership_type) { source.is_a?(Project) ? :project_member : :group_member }
      let!(:membership) { create(membership_type, :guest, member_role: role, user: user, source: source) if source }

      before do
        stub_licensed_features(custom_roles: true)
      end

      if params[:expected]
        it { is_expected.to be_allowed(user, ability, resource) }
      else
        it { is_expected.not_to be_allowed(user, ability, resource) }
      end

      context 'with a nil user' do
        it { is_expected.not_to be_allowed(nil, ability, resource) }
      end

      context 'with `custom_roles` disabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it { is_expected.not_to be_allowed(user, ability, resource) }
      end

      context 'when the permission is disabled' do
        before do
          allow(::MemberRole).to receive(:permission_enabled?).with(ability, user).and_return(false)
        end

        it { is_expected.not_to be_allowed(user, ability, resource) }
      end
    end

    context 'with an unknown ability' do
      it { is_expected.not_to be_allowed(user, :unknown, project) }
    end
  end
end
