# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updates an external status check', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:protected_branch) { create(:protected_branch, project: project) }

  let(:branch_rule) { ::Projects::BranchRule.new(project, protected_branch) }
  let(:external_status_check) do
    create(:external_status_check, project: project, protected_branches: [protected_branch])
  end

  let(:external_status_check_gid) { external_status_check.to_global_id.to_s }
  let(:branch_rule_gid) { branch_rule.to_global_id.to_s }
  let(:external_status_check_name) { 'Updated name' }
  let(:external_status_check_external_url) { 'https://external_url_updated.com' }

  let(:params) do
    {
      id: external_status_check_gid,
      branch_rule_id: branch_rule_gid,
      name: external_status_check_name,
      external_url: external_status_check_external_url
    }
  end

  let(:mutation) { graphql_mutation(:branch_rule_external_status_check_update, **params) }
  let(:mutation_response) { graphql_mutation_response(:branch_rule_external_status_check_update) }

  subject(:mutation_request) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'it expects value not to be null' do
    it 'does not update the external status check record' do
      expect { mutation_request }.to not_change { external_status_check }
    end

    it 'returns an error message' do
      mutation_request

      expected_message = 'Expected value to not be null'
      expect(graphql_errors).to include(a_hash_including('message' => a_string_including(expected_message)))
    end
  end

  context 'with valid params' do
    context 'when user is not authorized' do
      it 'returns an error' do
        expect { mutation_request }.to not_change { external_status_check }

        expected_message = "you don't have permission to perform this action"
        expect(graphql_errors).to include(a_hash_including('message' => a_string_including(expected_message)))
      end
    end

    context 'when user is authorized' do
      before_all do
        project.add_maintainer(current_user)
      end

      it 'updates the external status check' do
        mutation_request

        external_status_check.reload

        expect(external_status_check.name).to eq(external_status_check_name)
        expect(external_status_check.external_url).to eq(external_status_check_external_url)
        expect(mutation_response['externalStatusCheck']['name']).to eq(external_status_check_name)
        expect(mutation_response['externalStatusCheck']['externalUrl']).to eq(external_status_check_external_url)
        expect(graphql_errors).to be_nil
      end

      context 'when the service to update external checks return an error' do
        it 'does not update the external status check' do
          allow_next_found_instance_of(MergeRequests::ExternalStatusCheck) do |instance|
            allow(instance).to receive(:update).with(any_args).and_raise('Error!')
          end

          expect { mutation_request }.to not_change { external_status_check }

          expect(graphql_errors).to include(a_hash_including('message' => a_string_including('Error!')))
        end
      end
    end
  end

  context 'with invalid params' do
    context 'when the external_status_check GID is nil' do
      let(:external_status_check_gid) { nil }

      it_behaves_like 'it expects value not to be null'
    end

    context 'when the branch_rule GID is nil' do
      let(:branch_rule_gid) { nil }

      it_behaves_like 'it expects value not to be null'
    end

    context 'when the external_url is nil' do
      let(:external_status_check_external_url) { nil }

      it_behaves_like 'it expects value not to be null'
    end

    context 'when the name is nil' do
      let(:external_status_check_name) { nil }

      it_behaves_like 'it expects value not to be null'
    end
  end

  context 'with invalid global ids given' do
    context 'when branch_rule GID is invalid' do
      let(:branch_rule_gid) { project.to_gid.to_s }
      let(:error_message) { %("#{branch_rule_gid}" does not represent an instance of Projects::BranchRule) }
      let(:global_id_error) { a_hash_including('message' => a_string_including(error_message)) }

      it 'returns an error message' do
        expect { mutation_request }.to not_change { external_status_check }

        expect(graphql_errors).to include(global_id_error)
      end
    end

    context 'when external_check_rule GID is invalid' do
      let(:external_status_check_gid) { project.to_gid.to_s }

      let(:error_message) do
        %("#{external_status_check_gid}" does not represent an instance of MergeRequests::ExternalStatusCheck)
      end

      let(:global_id_error) { a_hash_including('message' => a_string_including(error_message)) }

      it 'returns an error message' do
        expect { mutation_request }.to not_change { external_status_check }

        expect(graphql_errors).to include(global_id_error)
      end
    end
  end
end
