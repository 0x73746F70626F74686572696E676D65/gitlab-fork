# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::RemoteDevelopment::Workspaces::Create::WorkspaceVariablesCreator, feature_category: :remote_development do
  include ResultMatchers

  include_context 'with remote development shared fixtures'

  let_it_be(:user) { create(:user) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:workspace) { create(:workspace, user: user, personal_access_token: personal_access_token) }
  let(:settings) { { some_setting: "context" } }
  let(:returned_workspace_variables) do
    [
      {
        key: "key1",
        value: "value1",
        variable_type: RemoteDevelopment::Workspaces::Create::WorkspaceVariables::VARIABLE_TYPE_FILE,
        workspace_id: workspace.id
      },
      {
        key: "key2",
        value: "value2",
        variable_type: variable_type,
        workspace_id: workspace.id
      }
    ]
  end

  let(:workspace_variables_params) do
    {
      name: workspace.name,
      dns_zone: workspace.dns_zone,
      personal_access_token_value: personal_access_token.token,
      user_name: user.name,
      user_email: user.email,
      workspace_id: workspace.id,
      settings: settings
    }
  end

  let(:context) do
    {
      workspace: workspace,
      personal_access_token: personal_access_token,
      current_user: user,
      settings: settings
    }
  end

  subject(:result) do
    described_class.create(context) # rubocop:disable Rails/SaveBang -- this is not an ActiveRecord method
  end

  before do
    allow(RemoteDevelopment::Workspaces::Create::WorkspaceVariables)
      .to receive(:variables).with(workspace_variables_params) { returned_workspace_variables }
  end

  context 'when workspace variables create is successful' do
    let(:valid_variable_type) { RemoteDevelopment::Workspaces::Create::WorkspaceVariables::VARIABLE_TYPE_ENV_VAR }
    let(:variable_type) { valid_variable_type }

    it 'creates the workspace variable records and returns ok result containing original context' do
      expect { result }.to change { workspace.workspace_variables.count }.by(2)

      expect(RemoteDevelopment::WorkspaceVariable.find_by_key('key1').value).to eq('value1')
      expect(RemoteDevelopment::WorkspaceVariable.find_by_key('key2').value).to eq('value2')

      expect(result).to be_ok_result(context)
    end
  end

  context 'when workspace create fails' do
    let(:invalid_variable_type) { 9999999 }
    let(:variable_type) { invalid_variable_type }

    it 'does not create the invalid workspace variable records and returns an error result with model errors' do
      # NOTE: Any valid records will be saved if they are first in the array before the invalid record, but that's OK,
      #       because if we return an err_result, the entire transaction will be rolled back at a higher level.
      expect { result }.to change { workspace.workspace_variables.count }.by(1)

      expect(RemoteDevelopment::WorkspaceVariable.find_by_key('key1').value).to eq('value1')
      expect(RemoteDevelopment::WorkspaceVariable.find_by_key('key2')).to be_nil

      expect(result).to be_err_result do |message|
        expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceVariablesModelCreateFailed)
        message.content => { errors: ActiveModel::Errors => errors }
        expect(errors.full_messages).to match([/variable type/i])
      end
    end
  end
end
