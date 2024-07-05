# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module TroubleshootJob
          class Executor < SlashCommandTool
            extend ::Gitlab::Utils::Override
            include Concerns::AiDependent
            include ::Gitlab::Utils::StrongMemoize

            NAME = 'TroubleshootJob'
            RESOURCE_NAME = 'Ci::Build'
            HUMAN_NAME = 'Troubleshoot Job'
            DESCRIPTION = 'Useful tool to troubleshoot job-related issues.'
            EXAMPLE = "Question: My job is failing with an error. How can I fix it and figure out why it failed? " \
              'Picked tools: "TroubleshootJob" tool. ' \
              'Reason: The question is about troubleshooting a job issue. "TroubleshootJob" tool ' \
              'can process this question.'
            PROVIDER_PROMPT_CLASSES = {
              ai_gateway: ::Gitlab::Llm::Chain::Tools::TroubleshootJob::Prompts::Anthropic,
              anthropic: ::Gitlab::Llm::Chain::Tools::TroubleshootJob::Prompts::Anthropic
            }.freeze

            PROMPT_TEMPLATE = [
              Utils::Prompt.as_system(
                <<~PROMPT
                  You are a Software engineer's or DevOps engineer's Assistant.
                  You can explain the root cause of a GitLab CI verification job code failure from the job log.
                  %<language_info>s
                PROMPT
              ),
              Utils::Prompt.as_user(
                <<~PROMPT.chomp
                  Below are the job logs surrounded by the xml tag: <log>

                  <log>
                    %<selected_text>s
                  <log>

                  %<input>s

                  Think step by step and try to determine why the job failed and explain it so that
                  any Software engineer could understand the root cause of the failure.
                  Please provide an example fix under the heading "Example Fix".
                  Any code blocks in response should be formatted in markdown.
                PROMPT
              )
            ].freeze

            SLASH_COMMANDS = {
              '/rca' => {
                description: 'Troubleshoot a job based on the logs.',
                instruction: 'Troubleshoot the job log.',
                instruction_with_input: "Troubleshoot the job log. Input: %<input>s."
              }
            }.freeze

            def self.slash_commands
              SLASH_COMMANDS
            end

            override :perform
            def perform
              error_message = if disabled?
                                _('This feature is not enabled yet.')
                              elsif !job.is_a?(::Ci::Build)
                                _('This command is used for troubleshooting jobs and can only be invoked from ' \
                                  'a job log page.')
                              elsif !job.failed?
                                _('This command is used for troubleshooting jobs and can only be invoked from ' \
                                  'a failed job log page.')
                              end

              return error_with_message(error_message) if error_message

              super
            end

            private

            def disabled?
              Feature.disabled?(:root_cause_analysis_duo, context.current_user)
            end

            def selected_text_options
              {
                selected_text: job_log,
                language_info: language_info
              }
            end

            def job_log
              # Line limit should be reworked based on
              # the results of the prompt library and prompt engineering.
              # 1000*100/4
              # 1000 lines, ~100 char per line (can be more), ~4 tokens per character
              # ~25000 tokens
              job.trace.raw(last_lines: 1000)
            end

            def job
              context.resource
            end
            strong_memoize_attr :job

            def authorize
              context.current_user.can?(:read_build_trace, job) &&
                Utils::ChatAuthorizer.context(context: context).allowed?
            end

            def resource_name
              RESOURCE_NAME
            end

            # Detects what code is used in the project
            # example return value:  "The repository code is written in Go, Ruby, Makefile, Shell and Dockerfile."
            def language_info
              language_names = job.project.repository_languages.map(&:name)
              return '' if language_names.empty?

              last_language = language_names.pop
              languages_comma_seperated = language_names.join(', ')

              if language_names.size >= 1
                "The repository code is written in #{languages_comma_seperated} and #{last_language}."
              else
                "The repository code is written in #{last_language}."
              end
            end
          end
        end
      end
    end
  end
end
