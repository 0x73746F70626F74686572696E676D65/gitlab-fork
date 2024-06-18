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
