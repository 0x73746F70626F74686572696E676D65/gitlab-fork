# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::GitlabCom::AccessDataReader, feature_category: :cloud_connector do
  describe '#read_available_services' do
    let_it_be(:cs_cut_off_date) { Time.zone.parse("2024-02-15 00:00:00 UTC").utc }
    let_it_be(:cs_unit_primitives) { [:code_suggestions] }
    let_it_be(:cs_bundled_with) { { "code_suggestions" => cs_unit_primitives } }

    let_it_be(:duo_chat_unit_primitives) { [:duo_chat, :documentation_search] }
    let_it_be(:duo_chat_bundled_with) { { "code_suggestions" => duo_chat_unit_primitives } }
    let_it_be(:backend) { 'gitlab-ai-gateway' }
    let_it_be(:ai_gateway_proxy_unit_primitives) do
      %i[
        analyze_ci_job_failure
        categorize_duo_chat_question
        documentation_search
        duo_chat
        explain_code
        explain_vulnerability
        fill_in_merge_request_template
        generate_commit_message
        generate_cube_query
        generate_issue_description
        resolve_vulnerability
        review_merge_request
        summarize_issue_discussions
        summarize_merge_request
        summarize_review
        summarize_submitted_review
      ]
    end

    let_it_be(:ai_gateway_proxy_bundled_with) { { "duo_enterprise" => ai_gateway_proxy_unit_primitives } }

    include_examples 'access data reader' do
      let_it_be(:available_service_data_class) { CloudConnector::GitlabCom::AvailableServiceData }
      let_it_be(:arguments_map) do
        {
          code_suggestions: [cs_cut_off_date, cs_bundled_with, backend],
          duo_chat: [nil, duo_chat_bundled_with, backend],
          ai_gateway_proxy: [nil, ai_gateway_proxy_bundled_with, backend]
        }
      end
    end
  end
end
