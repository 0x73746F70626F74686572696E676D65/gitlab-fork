# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::SelfSigned::AccessDataReader, feature_category: :cloud_connector do
  describe '#read_available_services' do
    let_it_be(:cs_cut_off_date) { Time.zone.parse("2024-02-15 00:00:00 UTC").utc }
    let_it_be(:cs_unit_primitives) { [:code_suggestions] }
    let_it_be(:cs_bundled_with) { { "duo_pro" => cs_unit_primitives } }

    let_it_be(:duo_chat_unit_primitives) { [:duo_chat, :documentation_search] }
    let_it_be(:duo_chat_bundled_with) { { "duo_pro" => duo_chat_unit_primitives } }
    let_it_be(:backend) { 'gitlab-ai-gateway' }

    let_it_be(:self_hosted_models_cut_off_date) { Time.zone.parse("2024-08-31 00:00:00 UTC").utc }
    let_it_be(:self_hosted_models_bundled_with) { { "duo_enterprise" => [:code_suggestions, :duo_chat] } }

    let_it_be(:anthropic_proxy_bundled_with) do
      {
        "duo_enterprise" => %i[
          categorize_duo_chat_question
          documentation_search
          explain_vulnerability
          resolve_vulnerability
          generate_issue_description
          summarize_issue_discussions
        ]
      }
    end

    let_it_be(:vertex_ai_proxy_bundled_with) do
      {
        "duo_enterprise" => %i[
          analyze_ci_job_failure
          documentation_search
          duo_chat
          explain_code
          explain_vulnerability
          generate_commit_message
          generate_cube_query
          resolve_vulnerability
          review_merge_request
          semantic_search_issue
          summarize_issue_discussions
          summarize_merge_request
          summarize_review
        ]
      }
    end

    let_it_be(:resolve_vulnerability_bundled_with) do
      {
        "duo_enterprise" => %i[
          resolve_vulnerability
        ]
      }
    end

    let_it_be(:generate_commit_message_bundled_with) do
      {
        "duo_enterprise" => %i[
          generate_commit_message
        ]
      }
    end

    include_examples 'access data reader' do
      let_it_be(:available_service_data_class) { CloudConnector::SelfSigned::AvailableServiceData }
      let_it_be(:arguments_map) do
        {
          code_suggestions: [cs_cut_off_date, cs_bundled_with, backend],
          duo_chat: [nil, duo_chat_bundled_with, backend],
          anthropic_proxy: [nil, anthropic_proxy_bundled_with, backend],
          vertex_ai_proxy: [nil, vertex_ai_proxy_bundled_with, backend],
          resolve_vulnerability: [nil, resolve_vulnerability_bundled_with, backend],
          self_hosted_models: [self_hosted_models_cut_off_date, self_hosted_models_bundled_with, backend],
          generate_commit_message: [nil, generate_commit_message_bundled_with, backend]
        }
      end
    end
  end
end
