# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Gitlab::Graphql::Tracers::Instrumentation integration test', :aggregate_failures, feature_category: :integrations do
  include GraphqlHelpers

  let_it_be(:user) { create(:user, username: 'instrumentation-tester') }

  describe "logging" do
    it "logs a message for each query in a request" do
      common_log_info = {
        "correlation_id" => be_a(String),
        :trace_type => "execute_query",
        :query_fingerprint => be_a(String),
        :duration_s => be_a(Float),
        :operation_fingerprint => be_a(String),
        "meta.remote_ip" => "127.0.0.1",
        "meta.feature_category" => "not_owned",
        "meta.user" => "instrumentation-tester",
        "meta.user_id" => user.id,
        "meta.client_id" => "user/#{user.id}",
        "query_analysis.duration_s" => be_a(Float),
        "meta.caller_id" => "graphql:unknown"
      }

      expect(Gitlab::GraphqlLogger).to receive(:info).with(a_hash_including({
        **common_log_info,
        variables: "{\"test\"=>\"hello world\"}",
        query_string: "{ echo(text: \"$test\") }"
      }))

      expect(Gitlab::GraphqlLogger).to receive(:info).with(a_hash_including({
        **common_log_info,
        variables: "{}",
        query_string: "{ currentUser{\n  username\n}\n }"
      }))

      queries = [
        { query: graphql_query_for('echo', { 'text' => '$test' }, []),
          variables: { test: "hello world" } },
        { query: graphql_query_for('currentUser', {}, ["username"]) }
      ]

      post_multiplex(queries, current_user: user)

      expect(json_response.size).to eq(2)
    end
  end

  describe "metrics" do
    it "tracks the apdex for each query" do
      expect(Gitlab::Metrics::RailsSlis.graphql_query_apdex).to receive(:increment).with({
        labels: {
          endpoint_id: "graphql:unknown",
          feature_category: 'not_owned',
          query_urgency: :default
        },
        success: be_in([true, false])
      })

      post_graphql(graphql_query_for('echo', { 'text' => 'test' }, []))
    end
  end

  it "recognizes known queries from our frontend" do
    query = <<~GQL
      query abuseReportQuery { currentUser{ username} }
    GQL

    expect(Gitlab::Metrics::RailsSlis.graphql_query_apdex).to receive(:increment).with({
      labels: {
        endpoint_id: "graphql:abuseReportQuery",
        feature_category: 'not_owned',
        query_urgency: :default
      },
      success: be_in([true, false])
    })

    expect(Gitlab::GraphqlLogger).to receive(:info).with(a_hash_including({
      "meta.caller_id" => "graphql:abuseReportQuery"
    }))

    post_graphql(query, current_user: user)
  end
end
