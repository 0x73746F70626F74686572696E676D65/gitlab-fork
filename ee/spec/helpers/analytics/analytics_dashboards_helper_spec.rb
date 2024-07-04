# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AnalyticsDashboardsHelper, feature_category: :product_analytics_data_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate
  let_it_be_with_refind(:project) { create(:project, group: group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:group_pointer) { create(:analytics_dashboards_pointer, namespace: group, target_project: project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :product_analytics) } # rubocop:disable RSpec/FactoryBot/AvoidCreate

  let(:product_analytics_instrumentation_key) { '1234567890' }

  before do
    allow(helper).to receive(:current_user) { user }
    allow(helper).to receive(:image_path).and_return('illustrations/chart-empty-state.svg')
    allow(helper).to receive(:project_analytics_dashboards_path).with(project).and_return('/-/analytics/dashboards')

    stub_application_setting(product_analytics_data_collector_host: 'https://new-collector.example.com')
    stub_application_setting(project_collector_host: 'https://project-collector.example.com')
    stub_application_setting(cube_api_base_url: 'https://cube.example.com')
    stub_application_setting(cube_api_key: '0987654321')
  end

  describe '#analytics_dashboards_list_app_data' do
    context 'for project' do
      where(
        :product_analytics_enabled_setting,
        :licensed_feature_enabled,
        :user_has_permission,
        :user_can_admin_project,
        :enabled
      ) do
        true  | true | true | true | true
        true  | true | true | false | true
        false | true | true | true | false
        true  | false | true | true | false
        true  | true | false | true | false
      end

      with_them do
        before do
          project.project_setting.update!(product_analytics_instrumentation_key: product_analytics_instrumentation_key)

          stub_application_setting(product_analytics_enabled: product_analytics_enabled_setting)

          stub_licensed_features(product_analytics: licensed_feature_enabled)

          allow(helper).to receive(:can?).with(user, :read_product_analytics, project).and_return(user_has_permission)
          allow(helper).to receive(:can?).with(user, :admin_project, project).and_return(user_can_admin_project)
          allow(helper).to receive(:can?).with(user, :generate_cube_query, project).and_return(false)
        end

        subject(:data) { helper.analytics_dashboards_list_app_data(project) }

        def expected_data(has_permission, pointer_project = project)
          {
            is_project: 'true',
            is_group: 'false',
            namespace_id: project.id,
            dashboard_project: {
              id: pointer_project.id,
              full_path: pointer_project.full_path,
              name: pointer_project.name,
              default_branch: pointer_project.default_branch
            }.to_json,
            can_configure_project_settings: user_can_admin_project.to_s,
            can_select_gitlab_managed_provider: 'false',
            managed_cluster_purchased: 'true',
            tracking_key: user_has_permission ? product_analytics_instrumentation_key : nil,
            collector_host: user_has_permission ? 'https://new-collector.example.com' : nil,
            chart_empty_state_illustration_path: 'illustrations/chart-empty-state.svg',
            dashboard_empty_state_illustration_path: 'illustrations/chart-empty-state.svg',
            analytics_settings_path: "/#{project.full_path}/-/settings/analytics#js-analytics-dashboards-settings",
            namespace_name: project.name,
            namespace_full_path: project.full_path,
            root_namespace_full_path: group.name,
            root_namespace_name: group.full_path,
            features: (enabled && has_permission ? [:product_analytics] : []).to_json,
            router_base: '/-/analytics/dashboards',
            ai_generate_cube_query_enabled: 'false',
            project_level_analytics_provider_settings: {
              product_analytics_configurator_connection_string: nil,
              product_analytics_data_collector_host: nil,
              cube_api_base_url: nil,
              cube_api_key: nil
            }.to_json,
            is_instance_configured_with_self_managed_analytics_provider: 'true',
            default_use_instance_configuration: 'true',
            overview_counts_aggregation_enabled: "false"
          }
        end

        context 'with snowplow' do
          before do
            stub_application_setting(product_analytics_configurator_connection_string: 'http://localhost:3000')
          end

          it 'returns the expected data' do
            expect(data).to eq(expected_data(true))
          end
        end

        context 'with value stream aggregation enabled' do
          before do
            create_value_stream_aggregation(project.root_ancestor)
          end

          it 'returns the expected data' do
            expect(data).to include({ overview_counts_aggregation_enabled: "true" })
          end
        end

        context 'with a dashboard pointer' do
          let_it_be(:pointer) { create(:analytics_dashboards_pointer, :project_based, project: project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate

          it 'returns the pointer target project in the expected data' do
            expect(data).to eq(expected_data(false, pointer.target_project))
          end
        end
      end
    end

    context 'for sub group' do
      let_it_be_with_refind(:sub_group) { create(:group, parent: group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate

      subject(:data) { helper.analytics_dashboards_list_app_data(sub_group) }

      def expected_data(collector_host)
        {
          is_project: 'false',
          is_group: 'true',
          namespace_id: sub_group.id,
          dashboard_project: nil,
          can_configure_project_settings: 'false',
          can_select_gitlab_managed_provider: 'false',
          managed_cluster_purchased: 'false',
          tracking_key: nil,
          collector_host: collector_host ? 'https://new-collector.example.com' : nil,
          chart_empty_state_illustration_path: 'illustrations/chart-empty-state.svg',
          dashboard_empty_state_illustration_path: 'illustrations/chart-empty-state.svg',
          analytics_settings_path: "/groups/#{sub_group.full_path}/-/edit#js-analytics-dashboards-settings",
          namespace_name: sub_group.name,
          namespace_full_path: sub_group.full_path,
          root_namespace_full_path: group.name,
          root_namespace_name: group.full_path,
          features: [].to_json,
          router_base: "/groups/#{sub_group.full_path}/-/analytics/dashboards",
          ai_generate_cube_query_enabled: 'false',
          project_level_analytics_provider_settings: nil,
          is_instance_configured_with_self_managed_analytics_provider: 'true',
          default_use_instance_configuration: 'true',
          overview_counts_aggregation_enabled: "false"
        }
      end

      context 'with value stream aggregation enabled' do
        before do
          create_value_stream_aggregation(sub_group.root_ancestor)
        end

        it 'returns the expected data' do
          expect(data).to include({ overview_counts_aggregation_enabled: "true" })
        end
      end

      context 'when user does not have permission' do
        before do
          allow(helper).to receive(:can?).with(user, :read_product_analytics, sub_group).and_return(false)
        end

        it 'returns the expected data' do
          expect(data).to eq(expected_data(false))
        end
      end

      context 'when user has permission' do
        before do
          allow(helper).to receive(:can?).with(user, :read_product_analytics, sub_group).and_return(true)
        end

        it 'returns the expected data' do
          expect(data).to eq(expected_data(true))
        end
      end
    end

    context 'for group' do
      subject(:data) { helper.analytics_dashboards_list_app_data(group) }

      def expected_data(collector_host)
        {
          is_project: 'false',
          is_group: 'true',
          namespace_id: group.id,
          dashboard_project: {
            id: group_pointer.target_project.id,
            full_path: group_pointer.target_project.full_path,
            name: group_pointer.target_project.name,
            default_branch: group_pointer.target_project.default_branch
          }.to_json,
          can_configure_project_settings: 'false',
          can_select_gitlab_managed_provider: 'false',
          managed_cluster_purchased: 'false',
          tracking_key: nil,
          collector_host: collector_host ? 'https://new-collector.example.com' : nil,
          chart_empty_state_illustration_path: 'illustrations/chart-empty-state.svg',
          dashboard_empty_state_illustration_path: 'illustrations/chart-empty-state.svg',
          analytics_settings_path: "/groups/#{group.full_path}/-/edit#js-analytics-dashboards-settings",
          namespace_name: group.name,
          namespace_full_path: group.full_path,
          root_namespace_full_path: group.name,
          root_namespace_name: group.full_path,
          features: [].to_json,
          router_base: "/groups/#{group.full_path}/-/analytics/dashboards",
          ai_generate_cube_query_enabled: 'false',
          project_level_analytics_provider_settings: nil,
          is_instance_configured_with_self_managed_analytics_provider: 'true',
          default_use_instance_configuration: 'true',
          overview_counts_aggregation_enabled: "false"
        }
      end

      context 'with value stream aggregation enabled' do
        before do
          create_value_stream_aggregation(group)
        end

        it 'returns the expected data' do
          expect(data).to include({ overview_counts_aggregation_enabled: "true" })
        end
      end

      context 'when user does not have permission' do
        before do
          allow(helper).to receive(:can?).with(user, :read_product_analytics, group).and_return(false)
        end

        it 'returns the expected data' do
          expect(data).to eq(expected_data(false))
        end
      end

      context 'when user has permission' do
        before do
          allow(helper).to receive(:can?).with(user, :read_product_analytics, group).and_return(true)
        end

        it 'returns the expected data' do
          expect(data).to eq(expected_data(true))
        end
      end
    end

    describe 'tracking_key' do
      where(
        :can_read_product_analytics,
        :project_instrumentation_key,
        :expected
      ) do
        false | nil | nil
        true | 'snowplow-key' | 'snowplow-key'
        true | nil | nil
      end

      with_them do
        before do
          project.project_setting.update!(product_analytics_instrumentation_key: project_instrumentation_key)

          stub_application_setting(product_analytics_configurator_connection_string: 'https://configurator.example.com')
          stub_application_setting(product_analytics_enabled: can_read_product_analytics)
          stub_licensed_features(product_analytics: can_read_product_analytics)
          allow(helper).to receive(:can?).with(user, :read_product_analytics,
            project).and_return(can_read_product_analytics)
          allow(helper).to receive(:can?).with(user, :admin_project, project).and_return(true)
          allow(helper).to receive(:can?).with(user, :generate_cube_query, project).and_return(false)
        end

        subject(:data) { helper.analytics_dashboards_list_app_data(project) }

        it 'returns the expected tracking_key' do
          expect(data[:tracking_key]).to eq(expected)
        end
      end
    end

    describe 'ai_generate_cube_query_enabled' do
      where(
        :is_project,
        :user_can_generate_cube_query,
        :expected
      ) do
        true  | true  | 'true'
        true  | false | 'false'
        false | true  | 'false'
        false | false | 'false'
      end

      with_them do
        before do
          project.project_setting.update!(product_analytics_instrumentation_key: 'snowplow-key')
          stub_application_setting(product_analytics_configurator_connection_string: 'https://configurator.example.com')
          stub_application_setting(product_analytics_enabled: true)
          stub_licensed_features(product_analytics: true)
          allow(helper).to receive(:can?).with(user, :read_product_analytics,
            is_project ? project : group).and_return(true)
          allow(helper).to receive(:can?).with(user, :admin_project, is_project ? project : group).and_return(true)
          allow(helper).to receive(:can?).with(user, :generate_cube_query,
            is_project ? project : group).and_return(user_can_generate_cube_query)
        end

        subject(:data) { helper.analytics_dashboards_list_app_data(is_project ? project : group) }

        it 'returns the expected tracking_key' do
          expect(data[:ai_generate_cube_query_enabled]).to eq(expected)
        end
      end
    end

    describe 'can_select_gitlab_managed_provider' do
      where(:is_project,
        :gitlab_com,
        :product_analytics_billing,
        :expected_value) do
        true  | true  | true  | true
        true  | true  | false | false
        true  | false | true  | false
        true  | false | false | false
        false | true  | true  | false
      end

      with_them do
        before do
          allow(Gitlab::CurrentSettings).to receive(:should_check_namespace_plan?).and_return(gitlab_com)
          stub_feature_flags(product_analytics_billing: product_analytics_billing)
        end

        subject(:data) { helper.analytics_dashboards_list_app_data(is_project ? project : group) }

        it 'returns the expected value' do
          expect(data[:can_select_gitlab_managed_provider]).to eq(expected_value.to_s)
        end
      end
    end

    describe '#managed_cluster_purchased' do
      where(:is_project, :purchased_product_analytics_add_on,
        :product_analytics_billing_override, :expected_value) do
        true | true  | true  | true
        true | true  | false | true
        true | false | true  | true
        true | false | false | false

        false | true   | true  | false
        false | true   | false | false
        false | false  | true  | false
        false | false  | false | false
      end

      with_them do
        before do
          if purchased_product_analytics_add_on
            create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: group, add_on: add_on) # rubocop:disable RSpec/FactoryBot/AvoidCreate
          end

          stub_feature_flags(product_analytics_billing_override: product_analytics_billing_override)
        end

        subject(:data) { helper.analytics_dashboards_list_app_data(is_project ? project : group) }

        it 'returns the expected value' do
          expect(data[:managed_cluster_purchased]).to eq(expected_value.to_s)
        end
      end
    end

    describe '#is_instance_configured_with_self_managed_analytics_provider?' do
      where(
        :is_project,
        :collector_host,
        :expected_value
      ) do
        true | nil | 'false'
        true | '' | 'false'
        true | 'self-managed.example.com' | 'true'
        true | 'collector.gl-product-analytics.com' | 'false'
        false | nil | 'false'
        false | '' | 'false'
        false | 'self-managed.example.com' | 'true'
        false | 'collector.gl-product-analytics.com' | 'false'
      end

      with_them do
        before do
          stub_application_setting(product_analytics_data_collector_host: collector_host)
        end

        subject(:data) { helper.analytics_dashboards_list_app_data(is_project ? project : group) }

        it 'returns the expected value' do
          expect(data[:is_instance_configured_with_self_managed_analytics_provider]).to eq(expected_value)
        end
      end
    end

    describe '#default_use_instance_configuration?' do
      where(
        :is_project,
        :instance_collector_host,
        :project_configurator_connection_string,
        :project_collector_host,
        :project_cube_api_base_url,
        :project_cube_api_key,
        :expected_value
      ) do
        # rubocop:disable Layout/LineLength -- lines are unwrappable
        true | 'https://self-managed.collector.example.com' | 'https://configurator.example.com' | 'https://collector.example.com' | 'https://cube.example.com' | '123-apikey' | 'false'
        true | 'https://gitlab-managed.collector.gl-product-analytics.com' | 'https://configurator.example.com' | 'https://collector.example.com' | 'https://cube.example.com' | '123-apikey' | 'false'

        false | 'https://self-managed.collector.example.com' | 'https://configurator.example.com' | 'https://collector.example.com' | 'https://cube.example.com' | '123-apikey' | 'true'
        false | 'https://gitlab-managed.collector.gl-product-analytics.com' | 'https://configurator.example.com' | 'https://collector.example.com' | 'https://cube.example.com' | '123-apikey' | 'true'
        # rubocop:enable Layout/LineLength
      end

      with_them do
        before do
          stub_application_setting(product_analytics_data_collector_host: instance_collector_host)

          project.create_project_setting!(
            product_analytics_configurator_connection_string: project_configurator_connection_string,
            product_analytics_data_collector_host: project_collector_host,
            cube_api_base_url: project_cube_api_base_url,
            cube_api_key: project_cube_api_key
          )
        end

        subject(:data) { helper.analytics_dashboards_list_app_data(is_project ? project : group) }

        it 'returns the expected value' do
          expect(data[:default_use_instance_configuration]).to eq(expected_value)
        end
      end
    end
  end

  describe '#analytics_project_settings_data' do
    where(
      :can_read_product_analytics,
      :project_instrumentation_key,
      :expected_tracking_key,
      :use_project_level
    ) do
      false | nil | nil | false
      true | 'snowplow-key' | 'snowplow-key' | false
      true | 'snowplow-key' | 'snowplow-key' | true
      true | nil | nil | false
    end

    with_them do
      before do
        project.project_setting.update!(
          product_analytics_instrumentation_key: project_instrumentation_key,
          product_analytics_data_collector_host:
            use_project_level ? 'https://project-collector.example.com' : 'https://new-collector.example.com',
          product_analytics_configurator_connection_string: 'http://test.net',
          cube_api_base_url: 'https://test.net:3000',
          cube_api_key: 'thisisasecretkey'
        )

        stub_application_setting(product_analytics_enabled: can_read_product_analytics)

        stub_licensed_features(product_analytics: can_read_product_analytics)

        allow(helper).to receive(:can?).with(user, :read_product_analytics,
          project).and_return(can_read_product_analytics)
      end

      subject(:data) { helper.analytics_project_settings_data(project) }

      it 'returns the expected data' do
        expected_collector = use_project_level ? 'https://project-collector.example.com' : 'https://new-collector.example.com'

        expect(data).to eq({
          tracking_key: can_read_product_analytics ? expected_tracking_key : nil,
          collector_host: can_read_product_analytics ? expected_collector : nil,
          dashboards_path: '/-/analytics/dashboards'
        })
      end
    end
  end

  def create_value_stream_aggregation(namespace)
    create(:value_stream_dashboard_aggregation, namespace: namespace, enabled: true) # rubocop:disable RSpec/FactoryBot/AvoidCreate
  end
end
