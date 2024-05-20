# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GraphQL', feature_category: :api do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :public) }
  let_it_be(:current_user) { create(:user, developer_of: [project]) }
  let_it_be(:resource) { create(:issue, project: project) }
  let(:params) { { chat: { resource_id: resource&.to_gid, content: "summarize" } } }
  let(:query) { graphql_query_for('echo', text: 'Hello world') }
  let(:mutation) { 'mutation { echoCreate(input: { messages: ["hello", "world"] }) { echoes } }' }
  let(:ai_mutation) { graphql_mutation(:ai_action, params) }

  let_it_be(:user) { create(:user) }

  describe 'authentication', :allow_forgery_protection do
    context 'with token authentication' do
      let(:token) { create(:personal_access_token, user: user) }

      context 'when the personal access token has ai_features scope' do
        before do
          token.update!(scopes: [:ai_features])
        end

        it 'they can perform an ai mutation' do
          expect_next_instance_of(Llm::ExecuteMethodService) do |service|
            expect(service).to receive(:execute)
              .and_return(ServiceResponse.success(
                payload: {
                  ai_message: instance_double(::Gitlab::Llm::AiMessage, request_id: 'abc123')
                }
              ))
          end

          post_graphql(ai_mutation.query, variables: ai_mutation.variables, headers: { 'PRIVATE-TOKEN' => token.token })

          expect(response).to have_gitlab_http_status(:ok)
          expect(graphql_mutation_response(:ai_action)['requestId']).to eq('abc123')
          expect(graphql_mutation_response(:ai_action)['errors']).to eq([])
        end

        it 'they cannot perform a non ai query' do
          post_graphql(query, headers: { 'PRIVATE-TOKEN' => token.token })

          # The response status is OK but they get no data back
          expect(response).to have_gitlab_http_status(:ok)

          expect(fresh_response_data['data']).to be_nil
        end

        it 'they cannot perform a non ai mutation' do
          post_graphql(mutation, headers: { 'PRIVATE-TOKEN' => token.token })

          # The response status is OK but they get no data back and they get errors
          expect(response).to have_gitlab_http_status(:ok)
          expect(graphql_data['echoCreate']).to be_nil

          expect_graphql_errors_to_include("does not exist or you don't have permission")
        end
      end
    end
  end
end
