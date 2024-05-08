# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create an external status check', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:protected_branch) { create(:protected_branch, project: project) }

  let(:branch_rule) { ::Projects::BranchRule.new(project, protected_branch) }
  let(:branch_rule_gid) { branch_rule.to_global_id.to_s }
  let(:status_check_name) { 'Test' }
  let(:external_url) { 'https://external_url.text/hello.json' }
  let(:params) { { branch_rule_id: branch_rule_gid, name: status_check_name, external_url: external_url } }
  let(:mutation) { graphql_mutation(:branch_rule_external_status_check_create, **params) }
  let(:mutation_response) { graphql_mutation_response(:branch_rule_external_status_check_create) }

  subject(:mutation_request) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'it expects value not to be null' do
    it 'returns error' do
      expect { mutation_request }.to change { MergeRequests::ExternalStatusCheck.count }.by(0)

      error_message = graphql_errors[0]["extensions"]["problems"][0]["explanation"]
      expect(error_message).to eq('Expected value to not be null')
    end
  end

  context 'with invalid params' do
    context 'when the branch rule GID is nil' do
      let(:branch_rule_gid) { nil }

      it_behaves_like 'it expects value not to be null'
    end

    context 'when an invalid global id is given' do
      let(:branch_rule_gid) { project.to_gid.to_s }
      let(:error_message) { %("#{branch_rule_gid}" does not represent an instance of Projects::BranchRule) }
      let(:global_id_error) { a_hash_including('message' => a_string_including(error_message)) }

      it 'returns an error' do
        expect { mutation_request }.to change { MergeRequests::ExternalStatusCheck.count }.by(0)

        expect(graphql_errors).to include(global_id_error)
      end
    end

    context 'when there is no external url' do
      let(:external_url) { nil }

      it_behaves_like 'it expects value not to be null'
    end

    context 'when there is no name' do
      let(:status_check_name) { nil }

      it_behaves_like 'it expects value not to be null'
    end
  end

  context 'with valid params' do
    context 'when user is not authorized' do
      it 'returns error' do
        expect { mutation_request }.to change { MergeRequests::ExternalStatusCheck.count }.by(0)

        expected_message = "you don't have permission to perform this action"
        expect(graphql_errors).to include(a_hash_including('message' => a_string_including(expected_message)))
      end
    end

    context 'when user is authorized' do
      before_all do
        project.add_maintainer(current_user)
      end

      it 'creates the external status check' do
        expect { mutation_request }.to change { MergeRequests::ExternalStatusCheck.count }.by(1)

        expect(mutation_response['externalStatusCheck']['name']).to eq(status_check_name)
        expect(mutation_response['externalStatusCheck']['externalUrl']).to eq(external_url)
        expect(graphql_errors).to be_nil
      end

      context 'when the service to create external checks return an error' do
        before do
          allow_next_instance_of(MergeRequests::ExternalStatusCheck) do |instance|
            allow(instance).to receive(:save).and_raise('Error!')
          end
        end

        it 'creates the external status check' do
          expect { mutation_request }.to change { MergeRequests::ExternalStatusCheck.count }.by(0)

          expect(graphql_errors).to include(a_hash_including('message' => a_string_including('Error!')))
        end
      end
    end
  end
end
