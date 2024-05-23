# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalyticsHelpers, feature_category: :product_analytics_data_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :product_analytics) }

  before do
    stub_feature_flags(product_analytics_billing_override: false)
  end

  describe '#product_analytics_enabled?' do
    subject { project.product_analytics_enabled? }

    where(:instance_enabled, :licensed, :toggle, :outcome) do
      false | false | false | false
      true  | false | false | false
      false | true  | false | false
      false | false | false | false
      false | false | true  | false
      false | true  | true  | false
      true  | true  | true  | true
    end

    with_them do
      before do
        allow(::Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(instance_enabled)
        allow(project.group.root_ancestor.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
        stub_licensed_features(product_analytics: licensed)
      end

      it { is_expected.to eq(outcome) }
    end
  end

  describe '#product_analytics_stored_events_limit' do
    subject { group.product_analytics_stored_events_limit }

    context 'when the product_analytics_billing flag is disabled' do
      before do
        stub_feature_flags(product_analytics_billing: false)
      end

      it { is_expected.to be_nil }
    end

    context 'when the product_analytics_billing flag is enabled' do
      before do
        stub_feature_flags(product_analytics_billing: group)
      end

      it { is_expected.to be_zero }

      context 'when 1 product_analytics add-on has been purchased' do
        before do
          create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: group, add_on: add_on)
        end

        it { is_expected.to eq(1_000_000) }
      end
    end

    context 'when 5 product_analytics add-on has been purchased' do
      before do
        create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: group, add_on: add_on, quantity: 5)
      end

      it { is_expected.to eq(5_000_000) }
    end
  end

  describe '#project_value_streams_dashboards_enabled?' do
    context 'with a project' do
      subject { project.project_value_streams_dashboards_enabled? }

      where(:flag, :outcome) do
        false | false
        true | true
      end

      with_them do
        before do
          stub_feature_flags(project_analytics_dashboard_dynamic_vsd: flag)
        end

        it { is_expected.to eq(outcome) }
      end
    end

    context 'with a group' do
      subject { group.project_value_streams_dashboards_enabled? }

      where(:flag, :outcome) do
        false | true
        true | true
      end

      with_them do
        before do
          stub_feature_flags(project_analytics_dashboard_dynamic_vsd: flag)
        end

        it { is_expected.to eq(outcome) }
      end
    end
  end

  describe '#ai_impact_dashboard_available?' do
    subject { group.ai_impact_dashboard_available? }

    where(:enabled, :outcome) do
      false | false
      true | true
    end

    with_them do
      before do
        allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(enabled)
      end

      it { is_expected.to eq(outcome) }
    end
  end

  describe '#product_analytics_dashboards' do
    it 'returns nothing if product analytics disabled' do
      stub_licensed_features(product_analytics: false)
      expect(project.product_analytics_dashboards(user)).to be_empty
    end

    context 'with configuration project' do
      let_it_be(:config_project) { create(:project, :with_product_analytics_dashboard, group: group) }

      before do
        allow(project.group.root_ancestor.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
        stub_licensed_features(product_analytics: true)
        project.update!(analytics_dashboards_configuration_project: config_project)
      end

      it 'includes configuration project dashboards' do
        expect(project.product_analytics_dashboards(user)).not_to be_empty
      end
    end

    context 'without configuration project' do
      before do
        allow(::Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return true
        allow(project.group.root_ancestor.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
        stub_licensed_features(product_analytics: true)
        project.project_setting.update!(product_analytics_instrumentation_key: "key")
        allow_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
          allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: {
            'results' => [{ "data" => [{ "TrackedEvents.count" => "1" }] }]
          }))
        end
      end

      it 'includes built in dashboards' do
        expect(project.product_analytics_dashboards(user).map(&:title))
          .to match_array(%w[Audience Behavior])
      end

      context 'when product analytics onboarding is incomplete' do
        before do
          project.project_setting.update!(product_analytics_instrumentation_key: nil)
        end

        it 'is empty' do
          expect(project.product_analytics_dashboards(user)).to be_empty
        end
      end
    end
  end

  describe '#product_analytics_funnels' do
    subject { create(:project, :with_product_analytics_funnel, group: group).product_analytics_funnels }

    before do
      allow(group.root_ancestor.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
    end

    context 'when the feature is not available' do
      before do
        stub_licensed_features(product_analytics: false)
      end

      it { is_expected.to be_empty }
    end

    context 'when the toggle is disabled' do
      before do
        stub_licensed_features(product_analytics: false)
        group.root_ancestor.namespace_settings.update!(product_analytics_enabled: false)
      end

      it { is_expected.to be_empty }
    end

    context 'when the feature is available and toggle is enabled' do
      before do
        stub_licensed_features(product_analytics: true)
        allow(::Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return true
        group.root_ancestor.namespace_settings.update!(product_analytics_enabled: true)
      end

      it { is_expected.to contain_exactly(a_kind_of(::ProductAnalytics::Funnel)) }

      context 'when the project has defined a configuration project' do
        let_it_be(:configuration_project) { create(:project, :with_product_analytics_funnel, group: group) }

        before do
          project.update!(analytics_dashboards_configuration_project: configuration_project)
        end

        it 'returns the funnels from the configuration project' do
          expect(project.product_analytics_funnels.first.config_project).to eq(configuration_project)
        end
      end
    end
  end

  describe '#product_analytics_dashboard' do
    context 'when product analytics is disabled' do
      before do
        stub_licensed_features(product_analytics: false)
      end

      it 'returns nil' do
        expect(project.product_analytics_dashboard('test', user)).to be_nil
      end
    end

    context 'when product analytics is available' do
      before do
        stub_licensed_features(product_analytics: true)
      end

      context 'when the project has defined a configuration project' do
        let_it_be(:configuration_project) { create(:project, :with_product_analytics_dashboard, group: group) }

        before do
          project.update!(analytics_dashboards_configuration_project: configuration_project)
        end

        context 'when the requested dashboard exists' do
          let(:slug) { 'dashboard_example_1' }

          it 'returns the dashboard with the given slug' do
            expect(project.product_analytics_dashboard(slug, user).container).to eq(project)
            expect(project.product_analytics_dashboard(slug, user).config_project).to eq(configuration_project)
          end
        end

        context 'when the requested dashboard does not exist' do
          let(:slug) { 'Dashboard Example 1800' }

          it 'returns nil' do
            expect(project.product_analytics_dashboard(slug, user)).to be_nil
          end
        end
      end
    end
  end

  describe '#connected_to_cluster?' do
    subject { project.connected_to_cluster? }

    before do
      stub_feature_flags(product_analytics_billing: project.root_ancestor)
      stub_application_setting(product_analytics_data_collector_host: 'https://gl-product-analytics.com:4567')
    end

    context 'when the product_analytics_billing flag is disabled' do
      before do
        stub_feature_flags(product_analytics_billing: false)
      end

      it { is_expected.to be_truthy }
    end

    context 'when the product_analytics_billing flag is enabled' do
      context 'when the product_analytics_billing_override flag is disabled' do
        before do
          stub_feature_flags(product_analytics_billing_override: false)
        end

        it { is_expected.to be_falsey }
      end

      context 'when product_analytics add on is not purchased' do
        it { is_expected.to be_falsey }

        context 'when user brings their own cluster' do
          before do
            stub_application_setting(product_analytics_data_collector_host: 'https://my-data-collector.customer-xyz.com')
          end

          it { is_expected.to be_truthy }
        end
      end

      context 'when product_analytics add on has been purchased' do
        before do
          create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: group, add_on: add_on)
        end

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#is_instance_configured_with_self_managed_analytics_provider' do
    subject { project.has_self_managed_collector?(collector_host) }

    describe 'with different collector host values' do
      where(:collector_host, :expected_result) do
        'self-managed.example.com'            | true
        'gl-product-analytics.com'            | false
        'subdomain.gl-product-analytics.com'  | false
        nil                                   | false
        ''                                    | false
      end

      with_them do
        it { is_expected.to eq(expected_result) }
      end
    end
  end
end
