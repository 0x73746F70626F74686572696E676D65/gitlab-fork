# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Product Analytics Project Settings Update", feature_category: :product_analytics_data_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let(:mutation) do
    params = {
      full_path: project.full_path,
      product_analytics_configurator_connection_string: "https://test:test@configurator.example.com",
      product_analytics_data_collector_host: "https://collector.example.com",
      cube_api_base_url: "https://cube.example.com",
      cube_api_key: "123-api-key"
    }

    graphql_mutation(:product_analytics_project_settings_update, params) do
      <<-QL.strip_heredoc
        productAnalyticsConfiguratorConnectionString
        productAnalyticsDataCollectorHost
        cubeApiBaseUrl
        cubeApiKey
        errors
      QL
    end
  end

  context 'when updating settings' do
    before_all do
      group.add_owner(user)
    end

    it 'updates the settings' do
      post_graphql_mutation(mutation, current_user: user)

      mutation_response = graphql_mutation_response(:product_analytics_project_settings_update)

      expect(mutation_response).to include(
        'productAnalyticsConfiguratorConnectionString' => 'https://test:test@configurator.example.com',
        'productAnalyticsDataCollectorHost' => 'https://collector.example.com',
        'cubeApiBaseUrl' => 'https://cube.example.com',
        'cubeApiKey' => '123-api-key'
      )
    end

    context 'when product_analytics_configurator_connection_string is provided' do
      it 'sets product_analytics_instrumentation_key to nil' do
        project.project_setting.update!(product_analytics_instrumentation_key: 'existing_key')

        post_graphql_mutation(mutation, current_user: user)

        expect(project.reload.project_setting.product_analytics_instrumentation_key).to be_nil
      end
    end
  end

  context 'when not authorized' do
    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: user)

      expected = "The resource that you are attempting to access does not exist or " \
                 "you don't have permission to perform this action"
      expect(graphql_errors).to include(a_hash_including('message' => expected))
    end
  end

  context 'when project is personal' do
    let_it_be(:namespace) { create(:namespace, owner: user) }
    let_it_be(:project) { create(:project, namespace: namespace) }

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: user)

      expected = "The resource that you are attempting to access does not exist or " \
                 "you don't have permission to perform this action"
      expect(graphql_errors).to include(a_hash_including('message' => expected))
    end
  end
end
