# frozen_string_literal: true

module Llm
  class GitCommandService < BaseService
    TEMPERATURE = 0.4
    INPUT_CONTENT_LIMIT = 300
    MAX_RESPONSE_TOKENS = 300

    def valid?
      super &&
        ::License.feature_available?(:ai_git_command) &&
        options[:prompt].size < INPUT_CONTENT_LIMIT
    end

    private

    def ai_action
      :ai_git_command
    end

    def perform
      config = ::Gitlab::Llm::VertexAi::Configuration.new(
        model_config: ::Gitlab::Llm::VertexAi::ModelConfigurations::CodeChat.new(user: user),
        user: user,
        unit_primitive: 'generate_commit_message'
      )

      payload = { url: config.url, headers: config.headers, body: config.payload(prompt).to_json }

      success(payload)
    end

    def prompt
      <<~TEMPLATE
      Provide the appropriate git commands for: #{options[:prompt]}.

      Respond with git commands wrapped in separate ``` blocks.
      Provide explanation for each command in a separate block.

      ##
      Example:

      ```
      git log -10
      ```

      This command will list the last 10 commits in the current branch.
      TEMPLATE
    end

    def json_prompt
      <<~TEMPLATE
      Provide the appropriate git commands for: #{options[:prompt]}.
      Respond with JSON format
      ##
      {
        "commands": [The list of commands],
        "explanation": The explanation with the commands wrapped in backticks
      }
      TEMPLATE
    end
  end
end
