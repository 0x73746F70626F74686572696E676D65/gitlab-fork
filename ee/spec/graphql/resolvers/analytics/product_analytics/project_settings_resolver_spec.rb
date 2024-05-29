# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Analytics::ProductAnalytics::ProjectSettingsResolver, feature_category: :product_analytics_data_management do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:result) { resolve(described_class, obj: project, ctx: { current_user: user }) }

    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }

    before do
      allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
      stub_licensed_features(product_analytics: true)
    end

    context 'when user has guest access' do
      before_all do
        project.add_guest(user)
      end

      it { is_expected.to be_nil }
    end

    context 'when user has developer access' do
      before_all do
        project.add_developer(user)
      end

      it { is_expected.to be_nil }
    end

    context 'when user has maintainer access' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when product analytics is not enabled for the project' do
        before do
          allow(project).to receive(:product_analytics_enabled).and_return(false)
        end

        it { is_expected.to be_nil }
      end

      context 'when product analytics is enabled for the project' do
        before do
          allow(project).to receive(:product_analytics_enabled?).and_return(true)

          project.project_setting.update!(
            product_analytics_configurator_connection_string: 'https://test:test@configurator.example.com',
            product_analytics_data_collector_host: 'https://collector.example.com',
            cube_api_base_url: 'https://cube.example.com',
            cube_api_key: '123-cube-api-key'
          )
        end

        it 'returns the project settings' do
          expect(result).to have_attributes(
            product_analytics_configurator_connection_string: 'https://test:test@configurator.example.com',
            product_analytics_data_collector_host: 'https://collector.example.com',
            cube_api_base_url: 'https://cube.example.com',
            cube_api_key: '123-cube-api-key'
          )
        end
      end
    end
  end
end
