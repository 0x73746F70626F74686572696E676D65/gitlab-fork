# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/settings/analytics/_custom_dashboard_projects.html.haml', feature_category: :product_analytics_data_management do
  let(:group) { build_stubbed(:group) }
  let(:project) { build_stubbed(:project, namespace: group) }

  before do
    assign(:project, project)
    allow(view).to receive(:expanded).and_return(true)
  end

  context 'when project analytics dashboards feature is unavailable' do
    before do
      allow(view).to receive(:project_analytics_dashboard_available?).with(project).and_return(false)
    end

    it 'does not render the custom dashboard settings' do
      expect(rendered).to be_empty
    end
  end

  context 'when project analytics dashboards feature is available' do
    before do
      allow(view).to receive(:project_analytics_dashboard_available?).with(project).and_return(true)
    end

    it 'renders a help link' do
      render

      expect(rendered).to have_link('Learn more',
        href: help_page_path('user/analytics/analytics_dashboards', anchor: 'change-the-location-of-dashboards'))
    end

    it 'renders a link to the project analytics dashboards' do
      render

      expect(rendered).to have_link('Analytics Dashboards', href: project_analytics_dashboards_path(project))
    end

    it 'renders the vue project select app' do
      render

      expect(rendered).to have_selector('.js-vue-project-select')
      expect(rendered).to have_selector("[data-group-id='#{project.root_namespace.id}']")
    end
  end
end
