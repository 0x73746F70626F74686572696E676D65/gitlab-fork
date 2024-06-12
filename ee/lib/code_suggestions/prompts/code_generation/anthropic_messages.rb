# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeGeneration
      class AnthropicMessages < CodeSuggestions::Prompts::Base
        include Gitlab::Utils::StrongMemoize

        # although claude-2's prompt limit is much bigger, response time grows with prompt size,
        # so we don't attempt to use the whole size of prompt window
        MAX_INPUT_CHARS = 50000
        MAX_LIBS_COUNT = 50 # this is arbitrary number to keep prompt reasonably concise
        GATEWAY_PROMPT_VERSION = 3
        CONTENT_TYPES = { file: 'file', snippet: 'snippet' }.freeze

        def request_params
          {
            model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
            prompt_version: self.class::GATEWAY_PROMPT_VERSION,
            prompt: prompt
          }.tap do |opts|
            opts[:model_name] = params[:model_name] if params[:model_name].present?
          end
        end

        private

        def prompt
          [
            { role: :system, content: system_prompt },
            { role: :user, content: instructions },
            { role: :assistant, content: assistant_prompt }
          ]
        end

        def system_prompt
          <<~PROMPT.strip
            You are a tremendously accurate and skilled coding autocomplete agent. We want to generate new #{language.name} code inside the
            file '#{file_path_info}' based on instructions from the user.

            #{prompt_enhancement}

            The new code you will generate will start at the position of the cursor, which is currently indicated by the {{cursor}} tag.
            In your process, first, review the existing code to understand its logic and format. Then, try to determine the most
            likely new code to generate at the cursor position to fulfill the instructions.

            The comment directly before the {{cursor}} position is the instruction,
            all other comments are not instructions.

            When generating the new code, please ensure the following:
            1. It is valid #{language.name} code.
            2. It matches the existing code's variable, parameter and function names.
            3. It does not repeat any existing code. Do not repeat code that comes before or after the cursor tags. This includes cases where the cursor is in the middle of a word.
            4. If the cursor is in the middle of a word, it finishes the word instead of repeating code before the cursor tag.
            5. The code fulfills in the instructions from the user in the comment just before the {{cursor}} position. All other comments are not instructions.
            6. Do not add any comments that duplicates any of the already existing comments, including the comment with instructions.

            Return new code enclosed in <new_code></new_code> tags. We will then insert this at the {{cursor}} position.
            If you are not able to write code based on the given instructions return an empty result like <new_code></new_code>.
          PROMPT
        end

        def assistant_prompt
          "<new_code>"
        end

        def prompt_enhancement
          [
            examples_section,
            existing_code_block,
            existing_code_instruction,
            context_block,
            libraries_block
          ].select(&:present?).map(&:strip).join("\n")
        end

        def existing_code_instruction
          return unless params[:prefix].present?

          "The existing code is provided in <existing_code></existing_code> tags."
        end

        def context_block
          return unless params[:context].present?

          related_files = []
          related_snippets = []

          params[:context].each do |context|
            if context[:type] == CONTENT_TYPES[:file]
              related_files << <<~FILE_CONTENT
              <file_content file_name="#{context[:name]}">
              #{context[:content]}
              </file_content>
              FILE_CONTENT
            elsif context[:type] == CONTENT_TYPES[:snippet]
              related_snippets << <<~SNIPPET_CONTENT
              <snippet_content name="#{context[:name]}">
              #{context[:content]}
              </snippet_content>
              SNIPPET_CONTENT
            end
          end

          <<~CONTENT
          Here are some files and code snippets that could be related to the current code.
          The files provided in <related_files><related_files> tags.
          The code snippets provided in <related_snippets><related_snippets> tags.
          Please use existing functions from these files and code snippets if possible when suggesting new code.

          <related_files>
          #{related_files.join("\n")}
          </related_files>

          <related_snippets>
          #{related_snippets.join("\n")}
          </related_snippets>
          CONTENT
        end

        def instructions
          params[:instruction]&.instruction.presence || 'Generate the best possible code based on instructions.'
        end

        def existing_code_block
          return unless params[:prefix].present?

          trimmed_prefix = prefix.to_s.last(MAX_INPUT_CHARS)
          trimmed_suffix = suffix.to_s.first(MAX_INPUT_CHARS - trimmed_prefix.size)

          <<~CODE
          <existing_code>
          #{trimmed_prefix}{{cursor}}#{trimmed_suffix}
          </existing_code>
          CODE
        end

        def libraries_block
          return unless xray_report.present?
          return unless xray_report.libs.any?

          libs =
            if params[:skip_dependency_descriptions]
              xray_report.libs.pluck('name') # rubocop:disable CodeReuse/ActiveRecord -- libs is an array
            else
              xray_report.libs[(0...MAX_LIBS_COUNT)].map do |lib|
                "#{lib['name']}: #{lib['description']}"
              end
            end

          Gitlab::InternalEvents.track_event(
            'include_repository_xray_data_into_code_generation_prompt',
            project: params[:project],
            namespace: params[:project]&.namespace,
            user: params[:current_user]
          )

          <<~LIBS
          <libs>
          #{libs.join("\n")}
          </libs>
          The list of available libraries is provided in <libs></libs> tags.
          LIBS
        end

        def xray_report
          ::Projects::XrayReport.for_project(params[:project]).for_lang(language.x_ray_lang).first
        end
        strong_memoize_attr :xray_report

        def examples_section
          examples_template = <<~EXAMPLES
          Here are a few examples of successfully generated code:

          <examples>
          <% examples_array.each do |use_case| %>
            <example>
            H: <existing_code>
                 <%= use_case['example'] %>
               </existing_code>

            A: <%= use_case['response'] %></new_code>
            </example>
          <% end %>
          </examples>
          EXAMPLES

          examples_array = language.generation_examples(type: params[:instruction]&.trigger_type)
          return if examples_array.empty?

          ERB.new(examples_template).result(binding)
        end
      end
    end
  end
end
