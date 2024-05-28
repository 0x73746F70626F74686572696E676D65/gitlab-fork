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
      nil | :admin_vulnerability | ref(:group) | false
      nil | :admin_vulnerability | ref(:project) | false
      nil | :read_code | ref(:group) | false
      nil | :read_code | ref(:project) | false
      nil | :read_dependency | ref(:group) | false
      nil | :read_dependency | ref(:group_runner) | false
      nil | :read_dependency | ref(:project) | false
      nil | :read_dependency | ref(:project_runner) | false
      nil | :read_vulnerability | ref(:group) | false
      nil | :read_vulnerability | ref(:project) | false
      ref(:child_group) | :admin_vulnerability | ref(:child_group) | true
      ref(:child_group) | :admin_vulnerability | ref(:child_project) | true
      ref(:child_group) | :admin_vulnerability | ref(:group) | false
      ref(:child_group) | :admin_vulnerability | ref(:project) | false
      ref(:child_group) | :admin_vulnerability | ref(:root_group) | false
      ref(:group) | :admin_vulnerability | ref(:group) | true
      ref(:group) | :admin_vulnerability | ref(:project) | true
      ref(:group) | :read_code | ref(:project) | true
      ref(:group) | :read_code | ref(:project) | true
      ref(:group) | :read_dependency | ref(:group) | true
      ref(:group) | :read_dependency | ref(:group_runner) | true
      ref(:group) | :read_dependency | ref(:project) | true
      ref(:group) | :read_dependency | ref(:project_runner) | true
      ref(:group) | :read_vulnerability | ref(:group) | true
      ref(:group) | :read_vulnerability | ref(:project) | true
      ref(:project) | :admin_vulnerability | ref(:group) | false
      ref(:project) | :admin_vulnerability | ref(:project) | true
      ref(:project) | :read_code | ref(:project) | true
      ref(:project) | :read_code | ref(:project) | true
      ref(:project) | :read_dependency | ref(:group) | false
      ref(:project) | :read_dependency | ref(:group_runner) | false
      ref(:project) | :read_dependency | ref(:project) | true
      ref(:project) | :read_dependency | ref(:project_runner) | true
      ref(:project) | :read_vulnerability | ref(:group) | false
      ref(:project) | :read_vulnerability | ref(:project) | true
      ref(:root_group) | :admin_vulnerability | ref(:child_group) | true
      ref(:root_group) | :admin_vulnerability | ref(:group) | true
      ref(:root_group) | :admin_vulnerability | ref(:project) | true
      ref(:root_group) | :admin_vulnerability | "unknown" | false
    end

    with_them do
      let!(:role) { create(:member_role, :guest, ability, namespace: root_group) }
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
