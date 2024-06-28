# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Analytics Visualization Designer', :js, feature_category: :product_analytics_visualization do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:user) { current_user }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:meta_response_with_data) { fixture_file('cube_js/meta_with_data.json', dir: 'ee') }
  let_it_be(:query_response_with_data) { fixture_file('cube_js/query_with_data.json', dir: 'ee') }
  let_it_be(:query_response_with_error) { fixture_file('cube_js/query_with_error.json', dir: 'ee') }

  let(:cube_meta_api_url) { "https://cube.example.com/cubejs-api/v1/meta" }
  let(:cube_dry_run_api_url) { "https://cube.example.com/cubejs-api/v1/dry-run" }
  let(:cube_load_api_url) { "https://cube.example.com/cubejs-api/v1/load" }

  subject(:visit_page) do
    visit project_analytics_dashboards_path(project)
    click_link "Visualization designer"
  end

  shared_examples 'valid visualization designer' do
    it 'renders the preview panels and the type selector' do
      visit_page

      expect(page).to have_content('Start by choosing a metric')
    end

    it 'renders the title input' do
      visit_page

      expect(page).to have_content('Visualization title')
    end

    it 'renders the type selector' do
      visit_page

      expect(page).to have_content('Visualization type')
    end
  end

  shared_examples 'selected measure behavior' do
    it 'selected measure behavior' do
      expect(find_by_testid('preview-visualization'))
        .to have_content('Event Count 335')
    end

    [
      {
        name: 'LineChart',
        text: 'Line chart',
        content: 'Snowplow Tracked Events Count'
      },
      {
        name: 'ColumnChart',
        text: 'Column chart',
        selector: 'dashboard-visualization-column-chart'
      },
      {
        name: 'DataTable',
        text: 'Data table',
        content: 'Count 335'
      },
      {
        name: 'SingleStat',
        text: 'Single statistic',
        content: '335'
      }
    ].each do |visualization|
      context "with #{visualization[:text]} visualization selected" do
        before do
          dropdown = find_by_testid('visualization-type-dropdown')
          dropdown.select visualization[:text]
        end

        it "shows the #{visualization[:text]} preview" do
          preview_panel = find_by_testid('preview-visualization')

          if visualization[:content].nil?
            expect(preview_panel).to have_selector("[data-testid=\"#{visualization[:selector]}\"]")
          else
            expect(preview_panel).to have_content(visualization[:content])
          end
        end

        context 'with the code tab selected' do
          before do
            within_testid 'query-builder' do
              click_button 'Code'
            end
          end

          it 'shows the visualization code' do
            yaml_snippet = "type: #{visualization[:name]}"
            expect(find_by_testid('preview-code')).to have_content(yaml_snippet)
          end
        end
      end
    end
  end

  context 'with all required access and analytics settings configured' do
    context 'when a custom dashboard project has not been configured' do
      it 'does not render the Visualization designer button' do
        setup_valid_state

        expect(page).not_to have_link(s_('Analytics|Visualization designer'))
      end
    end

    context 'when a custom dashboard project has been configured' do
      before do
        create(:analytics_dashboards_pointer, :project_based, project: project)
      end

      context 'when "analytics_visualization_designer_filtering" is true' do
        before do
          stub_feature_flags(analytics_visualization_designer_filtering: true)
          setup_valid_state
        end

        it_behaves_like 'valid visualization designer'

        it 'renders the filtered search query builder' do
          visit_page

          expect(page).to have_selector('[data-testid="visualization-filtered-search"]')
        end

        it 'does not render the measure selection' do
          visit_page

          expect(page).not_to have_content('What metric do you want to visualize?')
        end

        context 'with a measure selected' do
          before do
            visit_page
            select_all_views_measure
          end

          it_behaves_like 'selected measure behavior'
        end

        def select_all_views_measure
          find_by_testid('visualization-filtered-search').click
          find_by_testid('filtered-search-suggestion', text: 'Measure').click
          find_by_testid('filtered-search-suggestion', text: 'Tracked Events Count').click
        end
      end

      context 'when "analytics_visualization_designer_filtering" is false' do
        before do
          stub_feature_flags(analytics_visualization_designer_filtering: false)
          setup_valid_state
        end

        it_behaves_like 'valid visualization designer'

        it 'renders the measure selection & preview panels' do
          visit_page

          expect(page).to have_content('What metric do you want to visualize?')
          expect(page).to have_content('Start by choosing a metric')
        end

        it 'does not render the filtered search query builder' do
          visit_page

          expect(page).not_to have_selector('[data-testid="visualization-filtered-search"]')
        end

        context 'with a measure selected' do
          before do
            visit_page
            select_all_views_measure
          end

          it_behaves_like 'selected measure behavior'
        end

        context 'when data fails to load' do
          it 'shows error when selecting a measure fails' do
            visit_page

            stub_request(:post, cube_dry_run_api_url)
              .to_return(status: 200, body: query_response_with_error, headers: {})
            stub_request(:post, cube_load_api_url)
              .to_return(status: 200, body: query_response_with_error, headers: {})

            select_all_views_measure

            expect(page).to have_content('An error occurred while loading data')
          end
        end

        def select_all_views_measure
          click_button 'Events'
          click_button 'All Events Compared'
        end
      end
    end

    def setup_valid_state
      sign_in(user)
      stub_licensed_features(combined_project_analytics_dashboards: true, product_analytics: true)
      stub_application_setting(product_analytics_enabled?: true)
      stub_application_setting(product_analytics_data_collector_host: 'https://collector.example.com')
      stub_application_setting(product_analytics_configurator_connection_string: 'https://configurator.example.com')
      stub_application_setting(cube_api_base_url: 'https://cube.example.com')
      stub_application_setting(cube_api_key: '123')

      project.project_setting.update!({ product_analytics_instrumentation_key: 456 })
      project.add_developer(user)
      project.reload

      stub_request(:get, cube_meta_api_url)
        .to_return(status: 200, body: meta_response_with_data, headers: {})
      stub_request(:post, cube_dry_run_api_url)
        .to_return(status: 200, body: query_response_with_data, headers: {})
      stub_request(:post, cube_load_api_url)
        .to_return(status: 200, body: query_response_with_data, headers: {})
    end
  end
end
