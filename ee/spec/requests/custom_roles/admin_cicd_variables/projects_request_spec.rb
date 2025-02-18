# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_cicd_variables custom role', feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:role) { create(:member_role, :guest, namespace: group, admin_cicd_variables: true) }
  let_it_be(:member) { create(:project_member, :guest, member_role: role, user: user, project: project) }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(user)
  end

  describe Projects::Settings::CiCdController do
    describe '#show' do
      it 'user can view CI/CD settings page' do
        get project_settings_ci_cd_path(project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('CI/CD Settings')
      end
    end
  end

  describe 'Querying CI Variables and environment scopes' do
    include GraphqlHelpers

    let_it_be(:variable) { create(:ci_variable, project: project, key: 'new_key', value: 'dummy_value') }
    let_it_be(:inherited_variable) { create(:ci_group_variable, group: group, key: 'my_key') }

    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            ciVariables {
              nodes {
                key
                value
              }
            }
            inheritedCiVariables {
              nodes {
                key
              }
            }
          }
        }
      )
    end

    it 'returns variables and inherited variables for the project' do
      result = GitlabSchema.execute(query, context: { current_user: user }).as_json

      project_data = result.dig('data', 'project')

      expect(project_data.dig('ciVariables', 'nodes').first).to eq('key' => variable.key, 'value' => variable.value)
      expect(project_data.dig('inheritedCiVariables', 'nodes').first).to eq('key' => inherited_variable.key)
    end
  end

  describe Projects::VariablesController do
    describe '#update' do
      it 'user can create CI/CD variables' do
        params = { variables_attributes: [{ key: 'new_key', secret_value: 'dummy_value' }] }
        put project_variables_path(project, params: params, format: :json)

        expect(response).to have_gitlab_http_status(:ok)
        expect(Gitlab::Json.parse(response.body)['variables'][0])
          .to include('key' => 'new_key', 'value' => 'dummy_value')
      end

      it 'user can update CI/CD variables' do
        var = create(:ci_variable, project: project)

        params = { variables_attributes: [{ id: var.id, key: 'new_key', secret_value: 'dummy_value' }] }
        put project_variables_path(project, params: params, format: :json)

        expect(response).to have_gitlab_http_status(:ok)
        expect(Gitlab::Json.parse(response.body)['variables'][0])
          .to include('key' => 'new_key', 'value' => 'dummy_value')
      end

      it 'user can destroy CI/CD variables' do
        var = create(:ci_variable, project: project)

        params = { variables_attributes: [{ id: var.id, _destroy: 'true' }] }
        put project_variables_path(project, params: params, format: :json)

        expect(response).to have_gitlab_http_status(:ok)
        expect { var.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
