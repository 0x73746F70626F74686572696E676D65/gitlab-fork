# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::Dashboard, feature_category: :product_analytics_data_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_refind(:project) do
    create(:project, :repository,
      project_setting: build(:project_setting),
      group: group)
  end

  let_it_be(:config_project) do
    create(:project, :with_product_analytics_dashboard, group: group)
  end

  before do
    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
    stub_licensed_features(
      product_analytics: true,
      project_level_analytics_dashboard: true,
      group_level_analytics_dashboard: true
    )
  end

  shared_examples 'returns the value streams dashboard' do
    it 'returns the value streams dashboard' do
      expect(dashboard).to be_a(described_class)
      expect(dashboard.title).to eq('Value Streams Dashboard')
      expect(dashboard.slug).to eq('value_streams_dashboard')
      expect(dashboard.description).to eq('Track key DevSecOps metrics throughout the development lifecycle.')
      expect(dashboard.schema_version).to eq('2')
    end
  end

  describe '#errors' do
    let(:dashboard) do
      described_class.new(
        container: group,
        config: YAML.safe_load(config_yaml),
        slug: 'test2',
        user_defined: true,
        config_project: project
      )
    end

    context 'when yaml is valid' do
      let(:config_yaml) do
        File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read
      end

      it 'returns nil' do
        expect(dashboard.errors).to be_nil
      end
    end

    context 'when yaml is faulty' do
      let(:config_yaml) do
        <<-YAML
---
title: not good yaml
description: with missing properties
        YAML
      end

      it 'returns schema errors' do
        expect(dashboard.errors).to eq(["root is missing required keys: panels"])
      end
    end
  end

  describe '.for' do
    context 'when resource is a project' do
      let(:resource_parent) { project }

      subject { described_class.for(container: resource_parent, user: user) }

      before do
        allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
        allow(project.group.root_ancestor.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
        project.project_setting.update!(product_analytics_instrumentation_key: "key")
        allow_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
          allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: {
            'results' => [{ "data" => [{ "TrackedEvents.count" => "1" }] }]
          }))
        end
      end

      it 'returns a collection of builtin dashboards' do
        expect(subject.size).to eq(4)
        expect(subject.map(&:title)).to match_array(
          ['Audience', 'Behavior', 'Value Streams Dashboard', 'AI impact analytics']
        )
      end

      context 'when configuration project is set' do
        before do
          resource_parent.update!(analytics_dashboards_configuration_project: config_project)
        end

        it 'returns custom and builtin dashboards' do
          expect(subject).to be_a(Array)
          expect(subject.size).to eq(5)
          expect(subject.last).to be_a(described_class)
          expect(subject.last.title).to eq('Dashboard Example 1')
          expect(subject.last.slug).to eq('dashboard_example_1')
          expect(subject.last.description).to eq('North Star Metrics across all departments for the last 3 quarters.')
          expect(subject.last.schema_version).to eq('2')
          expect(subject.last.errors).to be_nil
        end
      end

      context 'when the dashboard file does not exist in the directory' do
        before do
          # Invalid dashboard - should not be included
          project.repository.create_file(
            project.creator,
            '.gitlab/analytics/dashboards/dashboard_example_1/project_dashboard_example_wrongly_named.yaml',
            File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read,
            message: 'test',
            branch_name: 'master'
          )

          # Valid dashboard - should be included
          project.repository.create_file(
            project.creator,
            '.gitlab/analytics/dashboards/dashboard_example_2/dashboard_example_2.yaml',
            File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read,
            message: 'test',
            branch_name: 'master'
          )
        end

        it 'excludes the dashboard from the list' do
          expected_dashboards =
            ["Audience", "Behavior", "Value Streams Dashboard", "AI impact analytics", "Dashboard Example 1"]

          expect(subject.map(&:title)).to eq(expected_dashboards)
        end
      end

      context 'when product analytics onboarding is incomplete' do
        before do
          project.project_setting.update!(product_analytics_instrumentation_key: nil)
        end

        it 'excludes product analytics dashboards' do
          expect(subject.size).to eq(3)
        end
      end
    end

    context 'when resource is a group' do
      let_it_be(:resource_parent) { group }

      subject { described_class.for(container: resource_parent, user: user) }

      it 'returns a collection of builtin dashboards' do
        expect(subject.size).to eq(2)
        expect(subject.map(&:title)).to match_array(['Value Streams Dashboard', 'AI impact analytics'])
      end

      context 'when configuration project is set' do
        before do
          resource_parent.update!(analytics_dashboards_configuration_project: config_project)
        end

        it 'returns custom and value stream dashboards' do
          expect(subject).to be_a(Array)
          expect(subject.size).to eq(3)
          expect(subject.map(&:title)).to match_array(
            ['Value Streams Dashboard', 'AI impact analytics', 'Dashboard Example 1']
          )
        end
      end

      context 'when the dashboard file does not exist in the directory' do
        before do
          project.repository.create_file(
            project.creator,
            '.gitlab/analytics/dashboards/dashboard_example_1/group_dashboard_example_wrongly_named.yaml',
            File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read,
            message: 'test',
            branch_name: 'master'
          )
        end

        it 'excludes the dashboard from the list' do
          expect(subject.size).to eq(3)
        end
      end
    end

    context 'when resource is not a project or a group' do
      it 'raises error' do
        invalid_object = double

        error_message =
          "A group or project must be provided. Given object is RSpec::Mocks::Double type"
        expect { described_class.for(container: invalid_object, user: user) }
          .to raise_error(ArgumentError, error_message)
      end
    end
  end

  describe '#panels' do
    before do
      project.update!(analytics_dashboards_configuration_project: config_project, namespace: config_project.namespace)
    end

    subject { described_class.for(container: project, user: user).last.panels }

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
        'timeDimensions' => [{
          'dimension' => 'Stories.time',
          'dateRange' => %w[2016-01-01 2016-02-30],
          'granularity' => 'month'
        }]
      })
    end
  end

  describe '#==' do
    let(:dashboard_1) { described_class.for(container: project, user: user).first }
    let(:dashboard_2) do
      config_yaml =
        File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read
      config_yaml = YAML.safe_load(config_yaml)

      described_class.new(
        container: project,
        config: config_yaml,
        slug: 'test2',
        user_defined: true,
        config_project: project
      )
    end

    subject { dashboard_1 == dashboard_2 }

    it { is_expected.to be false }
  end

  describe '.value_stream_dashboard' do
    context 'for groups' do
      let(:dashboard) { described_class.value_stream_dashboard(group, config_project) }

      it_behaves_like 'returns the value streams dashboard'

      it 'returns the correct panels' do
        expect(dashboard.panels.size).to eq(3)
        expect(dashboard.panels.map { |panel| panel.visualization.type }).to eq(
          %w[DORAChart UsageOverview DoraPerformersScore]
        )
      end
    end

    context 'for projects' do
      let(:dashboard) { described_class.value_stream_dashboard(project, config_project) }

      it_behaves_like 'returns the value streams dashboard'

      it 'returns the correct panels' do
        expect(dashboard.panels.size).to eq(2)
        expect(dashboard.panels.map { |panel| panel.visualization.type }).to eq(%w[DORAChart UsageOverview])
      end
    end

    context 'with the project_analytics_dashboard_dynamic_vsd feature flag disabled' do
      before do
        stub_feature_flags(project_analytics_dashboard_dynamic_vsd: false)
      end

      context 'for projects' do
        it 'returns nil' do
          dashboard = described_class.value_stream_dashboard(project, config_project)

          expect(dashboard).to be_nil
        end
      end

      context 'for groups' do
        let(:dashboard) { described_class.value_stream_dashboard(group, config_project) }

        it_behaves_like 'returns the value streams dashboard'

        it 'returns the correct panels' do
          expect(dashboard.panels.size).to eq(3)
          expect(dashboard.panels.map { |panel| panel.visualization.type }).to eq(
            %w[DORAChart UsageOverview DoraPerformersScore]
          )
        end
      end
    end
  end

  describe '.ai_impact_dashboard' do
    context 'for groups' do
      subject { described_class.ai_impact_dashboard(group, config_project) }

      it 'returns the dashboard' do
        expect(subject.title).to eq('AI impact analytics')
        expect(subject.slug).to eq('ai_impact')
        expect(subject.schema_version).to eq('2')
      end

      context 'when clickhouse is not enabled' do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        end

        it { is_expected.to be_nil }
      end
    end

    context 'for projects' do
      subject { described_class.ai_impact_dashboard(project, config_project) }

      it 'returns the dashboard' do
        expect(subject.title).to eq('AI impact analytics')
        expect(subject.slug).to eq('ai_impact')
        expect(subject.schema_version).to eq('2')
      end

      context 'when clickhouse is not enabled' do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        end

        it { is_expected.to be_nil }
      end
    end
  end

  describe '.load_yaml_dashboard_config' do
    let(:file_path) { '.gitlab/analytics/dashboards' }

    context 'when invalid path is provided' do
      it 'raises exception for absolute path traversal attempt' do
        invalid_file_name = '/tmp/foo'

        error_message = "path #{invalid_file_name} is not allowed"
        expect { described_class.load_yaml_dashboard_config(invalid_file_name, file_path) }
          .to raise_error(StandardError, error_message)
      end

      it 'raises exception when path traversal is attempted' do
        error_message = "Invalid path"
        expect { described_class.load_yaml_dashboard_config('../foo', file_path) }
          .to raise_error(Gitlab::PathTraversal::PathTraversalAttackError, error_message)
      end
    end

    context 'for valid path' do
      subject do
        described_class.load_yaml_dashboard_config('behavior',
          'ee/lib/gitlab/analytics/product_analytics/dashboards')
      end

      it 'loads the dashboard config' do
        expect(subject["title"]).to eq('Behavior')
        expect(subject.size).to eq(4)
      end
    end
  end
end
