# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      module Completions
        class GenerateDescription < Gitlab::Llm::Completions::Base
          OUTPUT_TOKEN_LIMIT = 8000

          def execute
            response = request!
            response_modifier = Gitlab::Llm::Anthropic::ResponseModifiers::GenerateDescription.new(response)

            ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
              user, issuable, response_modifier, options: response_options
            ).execute

            response_modifier
          end

          private

          def request!
            prompt_template = ai_prompt_class.new(prompt_message.content, template: template)

            ai_client = ::Gitlab::Llm::Anthropic::Client.new(user,
              unit_primitive: 'generate_issue_description', tracking_context: tracking_context)
            ai_client.complete(
              prompt: prompt_template.to_prompt,
              max_tokens_to_sample: OUTPUT_TOKEN_LIMIT,
              model: ::Gitlab::Llm::Concerns::AvailableModels::DEFAULT_INSTANT_MODEL
            )
          end

          def issuable
            resource
          end

          def template
            return if options[:description_template_name].blank? || !issuable.is_a?(Issue)

            begin
              TemplateFinder.new(
                :issues, issuable.project,
                name: options[:description_template_name]
              ).execute&.content
            rescue Gitlab::Template::Finders::RepoTemplateFinder::FileNotFoundError
              nil
            end
          end
        end
      end
    end
  end
end
