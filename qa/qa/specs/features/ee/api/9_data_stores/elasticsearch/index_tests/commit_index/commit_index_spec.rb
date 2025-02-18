# frozen_string_literal: true

require 'airborne'

module QA
  RSpec.describe 'Data Stores', product_group: :global_search do
    describe(
      'When using Advanced Search API to search for a public commit',
      :orchestrated,
      :elasticsearch,
      except: :production
    ) do
      include_context 'advanced search active'

      let(:api_client) { Runtime::API::Client.new(:gitlab) }
      let(:project) { create(:project, name: 'test-project-for-commit-index') }
      let(:content) { "Advanced search test commit #{SecureRandom.hex(8)}" }
      let(:commit) do
        create(:commit, project: project, commit_message: content, actions: [
          { action: 'create', file_path: 'test.txt', content: content }
        ])
      end

      it(
        'finds commit that matches commit message', :blocking,
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/367409'
      ) do
        QA::Support::Retrier.retry_on_exception(
          max_attempts: Runtime::Search::RETRY_MAX_ITERATION,
          sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL) do
          get(Runtime::Search.create_search_request(api_client, 'commits', commit.commit_message).url)

          aggregate_failures do
            expect_status(QA::Support::API::HTTP_STATUS_OK)
            expect(json_body).not_to be_empty, 'Expected a commit to be returned by search'
          end

          expect(json_body[0][:title]).to eq(commit.commit_message)
          expect(json_body[0][:short_id]).to eq(commit.short_id)
        end
      end
    end
  end
end
