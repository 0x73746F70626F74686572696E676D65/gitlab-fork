# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SearchController, :elastic, feature_category: :global_search do
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
  end

  shared_examples 'unique_users tracking' do |controller_action, tracked_action|
    let_it_be(:group) { create(:group) }

    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      allow(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)
    end

    describe 'Snowplow event tracking', :snowplow do
      let(:category) { described_class.to_s }

      subject { get controller_action, params: request_params }

      it 'emits all search events' do
        subject

        expect_snowplow_event(
          category: category, action: tracked_action, namespace: group, user: user,
          context: context('i_search_total'),
          property: 'i_search_total',
          label: 'redis_hll_counters.search.search_total_unique_counts_monthly'
        )
        expect_snowplow_event(
          category: category, action: tracked_action, namespace: group, user: user,
          context: context('i_search_paid'),
          property: 'i_search_paid',
          label: 'redis_hll_counters.search.i_search_paid_monthly'
        )
        expect_snowplow_event(
          category: category, action: tracked_action, namespace: group, user: user,
          context: context('i_search_advanced'),
          property: 'i_search_advanced',
          label: 'redis_hll_counters.search.search_total_unique_counts_monthly'
        )
      end
    end

    context 'i_search_advanced' do
      let(:target_event) { 'i_search_advanced' }

      subject(:request) { get controller_action, params: request_params }

      it_behaves_like 'tracking unique hll events' do
        let(:expected_value) { instance_of(String) }
      end
    end

    context 'i_search_paid' do
      let(:target_event) { 'i_search_paid' }

      context 'on Gitlab.com', :snowplow do
        subject(:request) { get controller_action, params: request_params }

        before do
          allow(::Gitlab).to receive(:com?).and_return(true)
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
        end

        it_behaves_like 'tracking unique hll events' do
          let(:expected_value) { instance_of(String) }
        end
      end

      context 'self-managed instance' do
        before do
          allow(::Gitlab).to receive(:com?).and_return(false)
        end

        context 'license is available' do
          before do
            stub_licensed_features(elastic_search: true)
          end

          it_behaves_like 'tracking unique hll events' do
            subject(:request) { get controller_action, params: request_params }

            let(:expected_value) { instance_of(String) }
          end
        end

        context 'feature is available through usage ping features' do
          before do
            allow(License).to receive(:current).and_return(nil)
            stub_ee_application_setting(usage_ping_enabled: true)
            stub_ee_application_setting(usage_ping_features_enabled: true)
          end

          it_behaves_like 'tracking unique hll events' do
            subject(:request) { get controller_action, params: request_params }

            let(:expected_value) { instance_of(String) }
          end
        end

        it 'does not track if there is no license available' do
          stub_licensed_features(elastic_search: false)
          expect(Gitlab::UsageDataCounters::HLLRedisCounter).not_to receive(:track_event).with(target_event, values: instance_of(String))

          get controller_action, params: request_params, format: :html
        end
      end
    end
  end

  describe 'GET #show' do
    it_behaves_like 'unique_users tracking', :show, 'executed' do
      let(:request_params) { { group_id: group.id, scope: 'blobs', search: 'term' } }
    end

    it_behaves_like 'support for elasticsearch timeouts', :show, { search: 'hello' }, :search_objects, :html

    describe 'when search_type is present in params' do
      it 'verifies search type' do
        expect_next_instance_of(SearchService) do |service|
          expect(service).to receive(:search_type_errors).once
        end

        get :show, params: { scope: 'blobs', search: 'test' }
      end

      using RSpec::Parameterized::TableSyntax

      where(:search_type, :scope, :use_elastic, :use_zoekt, :flash_expected) do
        'basic' | 'blobs' | false | false | false
        'advanced' | 'blobs' | false | false | true
        'advanced' | 'blobs' | true | false | false
        'zoekt' | 'blobs' | false | false | true
        'zoekt' | 'blobs' | false | true | false
        'zoekt' | 'issue' | false | true | true
      end

      with_them do
        before do
          allow_next_instance_of(SearchService) do |search_service|
            allow(search_service).to receive(:use_elasticsearch?).and_return(use_elastic)
            allow(search_service).to receive(:use_zoekt?).and_return(use_zoekt)
            allow(search_service).to receive(:scope).and_return(scope)
            allow(search_service).to receive(:search_objects).and_return([])
          end
        end

        it do
          get :show, params: { scope: scope, search: 'test', search_type: search_type }

          if flash_expected
            expect(controller).to set_flash[:alert]
          else
            expect(controller).not_to set_flash[:alert]
          end
        end
      end
    end
  end

  describe 'GET #autocomplete' do
    it_behaves_like 'unique_users tracking', :autocomplete, 'autocomplete' do
      let(:request_params) { { group_id: group.id, term: 'term' } }
    end
  end

  describe 'GET #aggregations' do
    it_behaves_like 'when the user cannot read cross project', :aggregations, { search: 'hello', scope: 'blobs' }
    it_behaves_like 'with external authorization service enabled', :aggregations, { search: 'hello', scope: 'blobs' }
    it_behaves_like 'support for elasticsearch timeouts', :aggregations, { search: 'hello', scope: 'blobs' }, :search_aggregations, :html

    it_behaves_like 'rate limited endpoint', rate_limit_key: :search_rate_limit do
      let(:current_user) { user }

      def request
        get(:aggregations, params: { search: 'foo@bar.com', scope: 'users' })
      end
    end

    context 'blobs scope' do
      context 'when elasticsearch is disabled' do
        it 'returns an empty array' do
          get :aggregations, params: { search: 'test', scope: 'blobs' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_empty
        end
      end

      context 'when elasticsearch is enabled', :sidekiq_inline do
        let(:project) { create(:project, :public, :repository) }

        before do
          stub_ee_application_setting(
            elasticsearch_search: true,
            elasticsearch_indexing: true
          )
          allow(::Search::Zoekt).to receive(:enabled_for_user?).and_return(false)

          project.repository.index_commits_and_blobs
          ensure_elasticsearch_index!
        end

        it 'returns aggregations' do
          get :aggregations, params: { search: 'test', scope: 'blobs' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.first['name']).to eq('language')
          expect(json_response.first['buckets'].length).to eq(2)
        end
      end
    end

    context 'issue scope' do
      context 'when elasticsearch is disabled' do
        it 'returns an empty array' do
          get :aggregations, params: { search: 'test', scope: 'issues' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_empty
        end
      end

      context 'when elasticsearch is enabled', :sidekiq_inline do
        let(:project) { create(:project) }

        before do
          stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

          create(:labeled_issue, title: 'test', project: project, labels: [create(:label)])
          project.add_developer(user)

          ensure_elasticsearch_index!
        end

        it 'returns aggregations' do
          get :aggregations, params: { search: 'test', scope: 'issues' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.first['name']).to eq('labels')
          expect(json_response.first['buckets'].length).to eq(1)
        end
      end
    end

    it 'raises an error if search term is missing' do
      expect do
        get :aggregations, params: { scope: 'projects' }
      end.to raise_error(ActionController::ParameterMissing)
    end

    it 'returns an error if search term is invalid' do
      search_term = 'a' * (::Gitlab::Search::Params::SEARCH_CHAR_LIMIT + 1)
      get :aggregations, params: { scope: 'blobs', search: search_term }

      expect(response).to have_gitlab_http_status(:bad_request)
      expect(json_response['error']).to include('Search query is too long')
    end

    it 'sets correct cache control headers' do
      get :aggregations, params: { search: 'test', scope: 'issues' }

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.headers['Cache-Control']).to eq('max-age=60, private')
      expect(response.headers['Pragma']).to be_nil
    end

    context 'when on gitlab.com' do
      before do
        allow(::Gitlab).to receive(:com?).and_return(true)
      end

      it 'sets correct cache control headers' do
        get :aggregations, params: { search: 'test', scope: 'issues' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['Cache-Control']).to eq('max-age=300, private')
        expect(response.headers['Pragma']).to be_nil
      end
    end
  end

  describe '#append_info_to_payload' do
    before do
      allow_next_instance_of(SearchService) do |service|
        allow(service).to receive(:use_elasticsearch?).and_return use_elasticsearch
      end
    end

    context 'when using elasticsearch' do
      let(:use_elasticsearch) { true }

      it 'appends the type of search used as advanced' do
        expect(controller).to receive(:append_info_to_payload).and_wrap_original do |method, payload|
          method.call(payload)

          expect(payload[:metadata]['meta.search.type']).to eq('advanced')
        end

        get :show, params: { search: 'hello world' }
      end
    end

    context 'when using basic search' do
      let(:use_elasticsearch) { false }

      it 'appends the type of search used as basic' do
        expect(controller).to receive(:append_info_to_payload).and_wrap_original do |method, payload|
          method.call(payload)

          expect(payload[:metadata]['meta.search.type']).to eq('basic')
        end

        get :show, params: { search: 'hello world', basic_search: true }
      end
    end
  end

  private

  def context(event)
    [Gitlab::Tracking::ServicePingContext.new(data_source: :redis_hll, event: event).to_context.to_json]
  end
end
