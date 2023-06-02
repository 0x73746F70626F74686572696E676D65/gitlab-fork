# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::Visualization, feature_category: :product_analytics do
  let_it_be(:project) do
    create(:project, :with_product_analytics_dashboard,
      project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
    )
  end

  let(:dashboards) { project.product_analytics_dashboards }

  before do
    stub_licensed_features(product_analytics: true)
  end

  shared_examples_for 'a valid visualization' do
    it 'returns a valid visualization' do
      expect(dashboard.panels.first.visualization).to be_a(described_class)
    end
  end

  describe '#slug' do
    subject { described_class.for_project(project).first.slug }

    it 'returns the slug' do
      expect(subject).to eq('daily_something')
    end
  end

  describe '.for_project' do
    subject { described_class.for_project(project) }

    it 'returns all visualizations stored in the project as well as built-in ones' do
      expect(subject.count).to eq(16)
      expect(subject.map { |v| v.config['type'] }).to include('BarChart', 'LineChart')
    end
  end

  context 'when dashboard is a built-in dashboard' do
    let(:dashboard) { dashboards.find { |d| d.title == 'Audience' } }

    it_behaves_like 'a valid visualization'
  end

  context 'when dashboard is a local dashboard' do
    let(:dashboard) { dashboards.find { |d| d.title == 'Dashboard Example 1' } }

    it_behaves_like 'a valid visualization'
  end

  context 'when visualization is loaded with attempted path traversal' do
    let_it_be(:project) do
      create(:project, :with_dashboard_attempting_path_traversal,
        project_setting: build(:project_setting, product_analytics_instrumentation_key: 'test')
      )
    end

    let(:dashboard) { dashboards.find { |d| d.title == 'Dashboard Example 1' } }

    it 'raises an error' do
      expect { dashboard.panels.first.visualization }.to raise_error(Gitlab::PathTraversal::PathTraversalAttackError)
    end
  end
end
