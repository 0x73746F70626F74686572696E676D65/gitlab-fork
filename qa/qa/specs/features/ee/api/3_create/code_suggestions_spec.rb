# frozen_string_literal: true

module QA
  RSpec.describe 'Create', product_group: :code_creation do
    include Support::API

    # These tests require several feature flags, user settings, and instance configurations.
    # See https://docs.gitlab.com/ee/development/code_suggestions/#code-suggestions-development-setup
    describe 'Code Suggestions' do
      # https://docs.gitlab.com/ee/api/code_suggestions.html#generate-code-completions-experiment
      shared_examples 'code suggestions API' do |testcase|
        let(:expected_response_data) do
          {
            id: 'id',
            model: {
              engine: anything,
              name: anything,
              lang: 'ruby'
            },
            object: 'text_completion',
            created: anything
          }
        end

        it 'returns a suggestion', testcase: testcase do
          response = get_suggestion(prompt_data)

          expect_status_code(200, response)

          actual_response_data = parse_body(response)
          expect(actual_response_data).to match(a_hash_including(expected_response_data))

          suggestion = actual_response_data.dig(:choices, 0, :text)
          expect(suggestion.length).to be > 0, 'The suggestion should not be blank'
        end
      end

      shared_examples 'code suggestions API using streaming' do |testcase|
        it 'streams a suggestion', testcase: testcase do
          response = get_suggestion(prompt_data)

          expect_status_code(200, response)

          expect(response.headers[:content_type].include?('event-stream')).to be_truthy, 'Expected an event stream'
          expect(response).not_to be_empty, 'Expected the first line of a stream'
        end
      end

      shared_examples 'unauthorized' do |testcase|
        it 'returns no suggestion', testcase: testcase do
          response = get_suggestion(prompt_data)

          expect_status_code(401, response)
        end
      end

      context 'when code completion' do
        # using a longer block of code to avoid SMALL_FILE_TRIGGER so we get code completion
        let(:content_above_cursor) do
          <<-RUBY_PROMPT.chomp
            class Vehicle
              attr_accessor :make, :model, :year

              def drive
                puts "Driving the \#{make} \#{model} from \#{year}."
              end

              def reverse
                puts "Reversing the \#{make} \#{model} from \#{year}."
              end

              def honk_horn(sound)
                puts "Beep beep the \#{make} \#{model} from \#{year} is honking its horn. \#{sound}"
              end
            end

            vehicle = Vehicle.new
            vehicle.
          RUBY_PROMPT
        end

        let(:prompt_data) do
          {
            prompt_version: 1,
            telemetry: [],
            current_file: {
              file_name: '/test.rb',
              content_above_cursor: content_above_cursor,
              content_below_cursor: "\n\n\n\n\n",
              language_identifier: 'ruby'
            },
            intent: 'completion'
          }.compact
        end

        context 'on SaaS', :external_ai_provider, only: { pipeline: %w[staging-canary staging canary production] } do
          it_behaves_like 'code suggestions API', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/436992'
        end

        context 'on Self-managed', :orchestrated do
          context 'with a valid license' do
            context 'with a Duo Pro add-on' do
              context 'when seat is assigned', :ai_gateway do
                it_behaves_like 'code suggestions API', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/436993'
              end
            end
          end
        end
      end

      context 'when code generation is requested' do
        let(:stream) { false }
        let(:prompt_data) do
          {
            prompt_version: 1,
            project_path: 'gitlab-org/gitlab',
            project_id: 278964,
            current_file: {
              file_name: '/http.rb',
              content_above_cursor: '# generate a http server',
              content_below_cursor: '',
              language_identifier: 'ruby'
            },
            stream: stream,
            intent: 'generation'
          }.compact
        end

        context 'on SaaS', :external_ai_provider, only: { pipeline: %w[staging-canary staging canary production] } do
          it_behaves_like 'code suggestions API', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/420973'
        end

        context 'on Self-managed', :orchestrated do
          context 'with a valid license' do
            context 'with a Duo Pro add-on' do
              context 'when seat is assigned', :ai_gateway do
                it_behaves_like 'code suggestions API', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/462967'
              end

              context 'when seat is not assigned', :ai_gateway_no_seat_assigned do
                it_behaves_like 'unauthorized', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/451487'
              end
            end

            context 'with no Duo Pro add-on', :ai_gateway_no_add_on do
              it_behaves_like 'unauthorized', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/452448'
            end
          end

          context 'with no license', :ai_gateway_no_license do
            it_behaves_like 'unauthorized', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/446249'
          end
        end

        context 'when streaming' do
          let(:stream) { true }

          context 'on SaaS', :external_ai_provider, only: { pipeline: %w[staging-canary staging canary production] } do
            it_behaves_like 'code suggestions API using streaming', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/436994'
          end

          context 'on Self-managed', :orchestrated do
            context 'with a valid license' do
              context 'with a Duo Pro add-on' do
                context 'when seat is assigned', :ai_gateway do
                  it_behaves_like 'code suggestions API using streaming', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/462968'
                end
              end
            end
          end
        end
      end

      def get_suggestion(prompt_data)
        response = post(
          "#{Runtime::Scenario.gitlab_address}/api/v4/code_suggestions/completions",
          JSON.dump(prompt_data),
          headers: {
            Authorization: "Bearer #{Resource::PersonalAccessToken.fabricate!.token}",
            'Content-Type': 'application/json'
          }
        )

        QA::Runtime::Logger.debug("Code Suggestion response: #{response}")
        response
      end

      def expect_status_code(expected_code, response)
        expect(response).not_to be_nil
        expect(response.code).to be(expected_code),
          "Expected (#{expected_code}), request returned (#{response.code}): `#{response}`"
      end
    end
  end
end
