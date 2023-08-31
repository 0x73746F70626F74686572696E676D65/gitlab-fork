# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::Dashboard, feature_category: :product_analytics_data_management do
  let_it_be(:project) do
    create(:project, :with_product_analytics_dashboard,
      project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
    )
  end

  let_it_be(:config_project) do
    create(:project, :with_product_analytics_dashboard)
  end

  before do
    # project_level_analytics_dashboard is used for the Value Stream Dashboard
    stub_licensed_features(product_analytics: true, project_level_analytics_dashboard: true)
  end

  describe '.for_project' do
    subject { described_class.for_project(project) }

    it 'returns a collection of dashboards' do
      expect(subject).to be_a(Array)
      expect(subject.size).to eq(4)
      expect(subject.last).to be_a(described_class)
      expect(subject.last.title).to eq('Dashboard Example 1')
      expect(subject.last.slug).to eq('dashboard_example_1')
      expect(subject.last.description).to eq('North Star Metrics across all departments for the last 3 quarters.')
      expect(subject.last.schema_version).to eq('1')
    end

    it 'without the `project_level_analytics_dashboard` license does not include Value Streams Dashboard' do
      stub_licensed_features(product_analytics: true, project_level_analytics_dashboard: false)
      expect(subject.map(&:title)).not_to include('Value Streams Dashboard')
    end

    context 'when product analytics is enabled' do
      it 'includes hardcoded dashboards' do
        expect(subject.size).to eq(4)
        expect(subject.map(&:title)).to include('Audience', 'Behavior', 'Value Stream Dashboard')
      end

      context 'when project has a configuration project assigned to it' do
        before do
          project.update!(analytics_dashboards_configuration_project: config_project)
        end

        it 'has all dashboards included hardcoded' do
          expect(subject.map(&:title)).to match_array([
            'Audience', 'Behavior', 'Dashboard Example 1', 'Value Stream Dashboard'
          ])
        end
      end
    end

    context 'when the project does not have a dashboards directory' do
      let_it_be(:project) { create(:project, :repository) }

      before do
        stub_licensed_features(project_level_analytics_dashboard: false)
      end

      it { is_expected.to be_empty }
    end

    context 'when the dashboard file does not exist in the directory' do
      before do
        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/dashboards/dashboard_example_1/dashboard_example_wrongly_named.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read,
          message: 'test',
          branch_name: 'master'
        )
      end

      it 'excludes the dashboard from the list' do
        expect(subject.size).to eq(4)
      end
    end

    context 'when the project does not have a dashboard directory' do
      let_it_be(:project) { create(:project) }

      before do
        stub_licensed_features(project_level_analytics_dashboard: false)
      end

      it 'returns an empty array' do
        expect(subject).to be_empty
      end
    end
  end

  describe '#panels' do
    subject { described_class.for_project(project).last.panels }

    it { is_expected.to be_a(Array) }

    it 'is expected to contain two panels' do
      expect(subject.size).to eq(2)
    end

    it 'is expected to contain a panel with the correct title' do
      expect(subject.first.title).to eq('Overall Conversion Rate')
    end

    it 'is expected to contain a panel with the correct grid attributes' do
      expect(subject.first.grid_attributes).to eq({ 'xPos' => 1, 'yPos' => 4, 'width' => 12, 'height' => 2 })
    end

    it 'is expected to contain a panel with the correct query overrides' do
      expect(subject.first.query_overrides).to eq({
        'timeDimensions' => {
          'dateRange' => ['2016-01-01', '2016-01-30'] # rubocop:disable Style/WordArray
        }
      })
    end
  end

  describe '#==' do
    let(:dashboard_1) { described_class.for_project(project).first }
    let(:dashboard_2) do
      described_class.new(
        title: 'a',
        description: 'b',
        schema_version: '1',
        panels: [],
        project: project,
        slug: 'test2',
        user_defined: true,
        config_project: project
      )
    end

    subject { dashboard_1 == dashboard_2 }

    it { is_expected.to be false }
  end

  describe '.value_stream_dashboard' do
    subject { described_class.value_stream_dashboard(project, config_project) }

    it 'returns the value stream dashboard' do
      dashboard = subject.first
      expect(dashboard).to be_a(described_class)
      expect(dashboard.title).to eq('Value Stream Dashboard')
      expect(dashboard.slug).to eq('value_stream_dashboard')
      expect(dashboard.description).to eq(
        'The Value Stream Dashboard allows all stakeholders from executives ' \
        'to individual contributors to identify trends, patterns, and ' \
        'opportunities for software development improvements.')
      expect(dashboard.schema_version).to eq(nil)
    end
  end
end
