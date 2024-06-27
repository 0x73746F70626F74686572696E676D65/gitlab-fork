# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating a self-hosted model', feature_category: :custom_models do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:self_hosted_model) do
    create(
      :ai_self_hosted_model,
      name: 'test-deployment',
      model: :mistral,
      endpoint: 'https://test-endpoint.com'
    )
  end

  let(:mutation_name) { :ai_self_hosted_model_update }
  let(:mutation_params) do
    {
      id: GitlabSchema.id_from_object(self_hosted_model).to_s,
      name: 'new-test-deployment',
      model: 'MIXTRAL',
      endpoint: 'https://new-test-endpoint.com',
      api_token: ''
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, mutation_params) }

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  describe '#resolve' do
    context 'when the ai_custom_model FF is disabled' do
      before do
        stub_feature_flags(ai_custom_model: false)
      end

      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when the user does not have write access' do
      let(:current_user) { create(:user) }

      it_behaves_like 'performs the right authorization'
      it_behaves_like 'a mutation that returns a top-level access error'
    end

    context 'when the user has write access' do
      it_behaves_like 'performs the right authorization'

      context 'when there are ActiveRecord validation errors' do
        let(:mutation_params) do
          {
            id: GitlabSchema.id_from_object(self_hosted_model).to_s,
            name: '',
            model: 'MIXTRAL',
            endpoint: 'https://new-test-endpoint.com',
            api_token: ''
          }
        end

        it 'returns an error' do
          request

          result = json_response['data']['aiSelfHostedModelUpdate']

          expect(result['selfHostedModel']).to eq(nil)
          expect(result['errors']).to eq(["Name can't be blank"])
        end

        it 'does not update the self-hosted model' do
          request

          expect { self_hosted_model.reload }.not_to change { self_hosted_model.name }
        end
      end

      context 'when required arguments are missing' do
        let(:mutation_params) { { id: GitlabSchema.id_from_object(self_hosted_model).to_s } }

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect_graphql_errors_to_include(/was provided invalid value for name \(Expected value to not be null\)/)
        end
      end

      context 'when there are no errors' do
        it 'updates the self-hosted model' do
          request

          expect(response).to have_gitlab_http_status(:success)

          expect(self_hosted_model.reload.name).to eq('new-test-deployment')
          expect(self_hosted_model.reload.model).to eq('mixtral')
          expect(self_hosted_model.reload.endpoint).to eq('https://new-test-endpoint.com')
        end
      end
    end
  end
end
