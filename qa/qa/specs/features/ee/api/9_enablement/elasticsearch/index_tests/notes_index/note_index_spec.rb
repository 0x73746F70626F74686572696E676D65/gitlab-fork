# frozen_string_literal: true

require 'airborne'

module QA
  RSpec.describe 'Enablement:Search' do
    describe 'When using elasticsearch API to search for a public note', :orchestrated, :elasticsearch, :requires_admin do
      let(:api_client) { Runtime::API::Client.new(:gitlab) }

      let(:issue) do
        Resource::Issue.fabricate_via_api! do |issue|
          issue.title = 'Issue for note index test'
        end
      end

      let(:note) do
        Resource::ProjectIssueNote.fabricate_via_api! do |project_issue_note|
          project_issue_note.project = issue.project
          project_issue_note.issue = issue
          project_issue_note.body = "This is a comment with a unique number #{SecureRandom.hex(8)}"
        end
      end

      let(:elasticsearch_original_state_on?) { Runtime::Search.elasticsearch_on?(api_client) }

      before do
        unless elasticsearch_original_state_on?
          QA::EE::Resource::Settings::Elasticsearch.fabricate_via_api!
        end
      end

      after do
        if !elasticsearch_original_state_on? && !api_client.nil?
          Runtime::Search.disable_elasticsearch(api_client)
        end

        issue.project.remove_via_api!
      end

      it 'finds note that matches note body', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347634' do
        QA::Support::Retrier.retry_on_exception(max_attempts: Runtime::Search::RETRY_MAX_ITERATION, sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL) do
          get Runtime::Search.create_search_request(api_client, 'notes', note.body).url
          expect_status(QA::Support::API::HTTP_STATUS_OK)

          raise 'Empty search result returned' if json_body.empty?

          expect(json_body[0][:body]).to eq(note.body)
          expect(json_body[0][:noteable_id]).to eq(issue.id)
        end
      end
    end
  end
end
