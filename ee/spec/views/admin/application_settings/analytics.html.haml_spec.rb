# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/analytics.html.haml', feature_category: :product_analytics_data_management do
  let_it_be(:user) { build_stubbed(:admin) }
  let_it_be(:app_settings) { build(:application_setting) }

  subject { rendered }

  before do
    assign(:application_setting, app_settings)
    allow(view).to receive(:current_user).and_return(user)
  end

  describe 'product analytics settings' do
    it 'renders the content' do
      render

      expect(rendered).to have_css "[data-name='application_setting[product_analytics_configurator_connection_string]']"
      expect(rendered).to have_field s_('AdminSettings|Collector host')
      expect(rendered).to have_field s_('AdminSettings|Cube API URL')
      expect(rendered).to have_css "[data-name='application_setting[cube_api_key]']"
    end
  end
end
