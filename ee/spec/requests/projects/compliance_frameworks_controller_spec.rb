# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ComplianceFrameworksController, feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }

  before do
    stub_licensed_features(compliance_framework: true, custom_compliance_frameworks: true, custom_roles: true)

    login_as(user)
  end

  describe 'POST #create' do
    let(:params) { { framework: framework.id } }

    subject(:assign_framework) { post project_compliance_frameworks_path(project), params: params }

    shared_examples 'setting compliance framework' do
      it 'redirects with notice message' do
        assign_framework

        expect(response).to redirect_to(edit_project_path(project, anchor: 'js-general-project-settings'))
        expect(flash[:notice]).to eq("Project '#{project.name}' was successfully updated.")
      end

      it 'sets the compliance framework' do
        assign_framework

        expect(project.reload.compliance_framework_settings.first.compliance_management_framework).to eq(framework)
      end
    end

    context 'when user is a project owner' do
      before_all do
        project.add_owner(user)
      end

      it_behaves_like 'setting compliance framework'
    end

    context 'when user has the permission because of a custom role' do
      let_it_be(:role) { create(:member_role, :guest, namespace: group, admin_compliance_framework: true) }
      let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, group: group) }

      it_behaves_like 'setting compliance framework'
    end

    context 'when user does not have permissions to update the framework' do
      it 'returns a 404' do
        assign_framework

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
