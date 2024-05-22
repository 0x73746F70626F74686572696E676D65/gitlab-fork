# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(id).dashboards.panels(id).visualization', feature_category: :product_analytics_visualization do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :with_product_analytics_dashboard) }

  let(:query) do
    <<~GRAPHQL
      query {
        project(fullPath: "#{project.full_path}") {
          name
          customizableDashboards {
            nodes {
              title
              slug
              description
              panels {
                nodes {
                  title
                  gridAttributes
                  visualization {
                    type
                    options
                    data
                    errors
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL
  end

  before do
    stub_licensed_features(product_analytics: true)
  end

  context 'when current user is a developer' do
    let_it_be(:user) { create(:user, developer_of: project) }

    it 'returns visualization' do
      get_graphql(query, current_user: user)

      expect(
        graphql_data_at(:project, :customizable_dashboards, :nodes, 0, :panels, :nodes, 0, :visualization, :type)
      ).to eq('AiImpactTable')
    end

    context 'when the visualization does not exist' do
      before do
        allow_next_instance_of(ProductAnalytics::Panel) do |panel|
          allow(panel).to receive(:visualization).and_return(nil)
        end
      end

      it 'returns an error' do
        get_graphql(query, current_user: user)

        expect(graphql_errors).to include(a_hash_including('message' => 'Visualization does not exist'))
      end
    end

    context 'when `ai_impact_analytics_dashboard` is disabled' do
      before do
        stub_feature_flags(ai_impact_analytics_dashboard: false)
      end

      it 'does not return the `AiImpactTable` visualization' do
        get_graphql(query, current_user: user)

        expect(
          graphql_data_at(:project, :customizable_dashboards, :nodes, 0, :panels, :nodes, 0, :visualization, :type)
        ).to eq('LineChart')
      end
    end

    context 'when an older VSD config has missing visualization' do
      let_it_be(:project) { create(:project, :with_product_analytics_invalid_custom_visualization) }
      let_it_be(:user) { create(:user, developer_of: project) }

      let(:slug) { "value_streams" }
      let(:query) do
        <<~GRAPHQL
          query {
            project(fullPath: "#{project.full_path}") {
              customizableDashboards(slug: "#{slug}") {
                nodes {
                  slug
                  description
                  panels {
                    nodes {
                      title
                      visualization {
                        slug
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      let(:config_without_visualization) do
        {
          'title' => 'test title',
          'description' => 'description',
          'panels' => [
            {
              'title' => 'My custom dashboard',
              'slug' => 'test',
              'data' => {
                'namespace' => 'group/my-custom-project'
              }
            }
          ]
        }
      end

      before do
        stub_feature_flags(project_analytics_dashboard_dynamic_vsd: true)

        other_project = create(:project, :repository, namespace: project.namespace)
        other_project.repository.create_file(
          other_project.creator,
          '.gitlab/analytics/dashboards/value_streams/value_streams.yaml',
          YAML.dump(config_without_visualization),
          message: 'commit default VSD config',
          branch_name: 'master'
        )

        create(:analytics_dashboards_pointer, :project_based, project: project, target_project: other_project)
      end

      it 'includes global error in the response about the missing visualization' do
        get_graphql(query, current_user: user)

        expect(graphql_data_at(:project, :customizable_dashboards, :nodes, 0, :slug)).to eq('value_streams')

        global_error = json_response['errors'].first
        expect(global_error['message']).to eq('Visualization does not exist')
      end
    end

    context 'when the visualization has validation errors' do
      let_it_be(:project) { create(:project, :with_product_analytics_invalid_custom_visualization) }
      let_it_be(:user) { create(:user, developer_of: project) }

      let(:slug) { "dashboard_example_invalid_vis" }
      let(:query) do
        <<~GRAPHQL
          query {
            project(fullPath: "#{project.full_path}") {
              customizableDashboards(slug: "#{slug}") {
                nodes {
                  panels {
                    nodes {
                      visualization {
                        errors
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      it 'returns the visualization with a validation error' do
        get_graphql(query, current_user: user)

        expect(
          graphql_data_at(:project, :customizable_dashboards, :nodes, 0,
            :panels, :nodes, 0, :visualization, :errors, 0))
          .to eq("property '/type' is not one of: " \
                 "[\"LineChart\", \"ColumnChart\", \"DataTable\", \"SingleStat\", " \
                 "\"DORAChart\", \"UsageOverview\", \"DoraPerformersScore\", \"AiImpactTable\"]")
      end
    end
  end
end
