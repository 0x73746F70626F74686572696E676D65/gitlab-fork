# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath)', feature_category: :product_analytics_data_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :with_product_analytics_dashboard, group: group) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :product_analytics) }
  let_it_be(:purchase) do
    create(:gitlab_subscription_add_on_purchase, :product_analytics, namespace: group, add_on: add_on)
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:settings) { build(:application_setting, product_analytics_enabled: true) }

  let_it_be(:events_table) { 'TrackedEvents.count' }

  context 'with trackingKey' do
    let_it_be(:query) do
      %(
      query {
        project(fullPath: "#{project.full_path}") {
          trackingKey
        }
      }
    )
    end

    subject(:result) do
      GitlabSchema.execute(query, context: { current_user: user }).as_json.dig('data', 'project', 'trackingKey')
    end

    using RSpec::Parameterized::TableSyntax

    where(:licensed, :user_role, :snowplow_instrumentation_key, :output) do
      true  | :developer | nil | nil
      true  | :developer | 'snowplow_key' | 'snowplow_key'
      true  | :developer | nil | nil
      false | :developer | nil | nil
      false | :developer | nil | nil
      true  | :maintainer | nil | nil
      true  | :maintainer | 'snowplow_key' | 'snowplow_key'
      true  | :maintainer | nil | nil
      false | :maintainer | nil | nil
      false | :maintainer | nil | nil
      true  | :owner | nil | nil
      true  | :owner | 'snowplow_key' | 'snowplow_key'
      true  | :owner | nil | nil
      false | :owner | nil | nil
      false | :owner | nil | nil
      true  | :guest | nil | nil
      true  | :guest | nil | nil
      false | :guest | nil | nil
      false | :guest | nil | nil
    end

    with_them do
      before do
        allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
        stub_licensed_features(product_analytics: licensed)
        project.add_role(user, user_role) # rubocop:disable RSpec/BeforeAllRoleAssignment
        project.project_setting.update!(product_analytics_instrumentation_key: snowplow_instrumentation_key)
        project.reload
      end

      it { is_expected.to eq(output) }
    end
  end

  context 'with productAnalyticsState' do
    let_it_be(:query) do
      %(
      query {
        project(fullPath: "#{project.full_path}") {
          id
          productAnalyticsState
        }
      }
    )
    end

    shared_examples_for 'queries state successfully' do
      it 'will query state correctly' do
        expect_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
          expect(instance).to receive(:execute).and_return(
            ServiceResponse.success(
              message: 'test success',
              payload: {
                'results' => [{ 'data' => [{ events_table => 1 }] }]
              }))
        end

        expect(result.dig('data', 'project', 'productAnalyticsState')).to eq('COMPLETE')
      end
    end

    before do
      allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
      stub_licensed_features(product_analytics: true)
      stub_application_setting(product_analytics_enabled: true)
      stub_feature_flags(product_analytics_billing_override: false)
      allow_next_instance_of(ProjectSetting) do |instance|
        allow(instance).to receive(:product_analytics_instrumentation_key).and_return('test key')
      end

      allow_next_instance_of(Resolvers::ProductAnalytics::StateResolver) do |instance|
        allow(instance).to receive(:initializing?).and_return(false)
      end

      project.reload
    end

    before_all do
      project.add_developer(user)
    end

    subject(:result) do
      GitlabSchema.execute(query, context: { current_user: user })
                  .as_json
    end

    it_behaves_like 'queries state successfully'

    it 'will pass through Cube API errors' do
      expect_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
        expect(instance).to receive(:execute).and_return(
          ServiceResponse.error(
            message: 'Error',
            reason: :bad_gateway,
            payload: {
              'error' => 'Test Error'
            }))
      end

      expect(result.dig('errors', 0, 'message')).to eq('Error from Cube API: Test Error')
    end

    it 'will query state when Cube DB does not exist' do
      expect_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
        expect(instance).to receive(:execute).and_return(
          ServiceResponse.error(
            message: '404 Clickhouse Database Not Found', reason: :not_found))
      end

      expect(result.dig('data', 'project', 'productAnalyticsState')).to eq('WAITING_FOR_EVENTS')
    end

    it 'will pass through Cube API connection errors' do
      expect_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |instance|
        expect(instance).to receive(:execute).and_return(ServiceResponse.error(message: 'Connection Error'))
      end

      expect(result.dig('errors', 0, 'message')).to eq('Error from Cube API: Connection Error')
    end

    context "when onboarded but there is no active addon subscription" do
      before do
        purchase.update!(expires_on: 1.day.ago)
      end

      it 'returns create_instance if connected to gitlab instance' do
        expect(result.dig('data', 'project', 'productAnalyticsState')).to eq('CREATE_INSTANCE')
      end

      it 'returns waiting_for_events if connected to own cluster' do
        allow(project).to receive(:self_managed_product_analytics_cluster?).and_return(true)
        expect(result.dig('data', 'project', 'productAnalyticsState')).to eq('WAITING_FOR_EVENTS')
      end
    end
  end
end
