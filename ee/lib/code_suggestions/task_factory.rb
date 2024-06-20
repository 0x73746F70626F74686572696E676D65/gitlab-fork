# frozen_string_literal: true

module CodeSuggestions
  class TaskFactory
    include Gitlab::Utils::StrongMemoize

    VERTEX_AI = :vertex_ai
    ANTHROPIC = :anthropic
    ANTHROPIC_MODEL = 'claude-3-sonnet-20240229'

    def initialize(current_user, params:, unsafe_passthrough_params: {})
      @current_user = current_user
      @params = params
      @params = params.except(:user_instruction, :context) if Feature.disabled?(:code_suggestions_context, current_user)
      @unsafe_passthrough_params = unsafe_passthrough_params

      @prefix = params.dig(:current_file, :content_above_cursor)
      @suffix = params.dig(:current_file, :content_below_cursor)
      @intent = params[:intent]
    end

    def task
      trim_context!

      instruction = extract_instruction(CodeSuggestions::FileContent.new(language, prefix, suffix))

      return code_completion_task unless instruction

      code_generation_task(instruction)
    end

    private

    attr_reader :current_user, :params, :unsafe_passthrough_params, :prefix, :suffix, :intent

    def extract_instruction(file_content)
      CodeSuggestions::InstructionsExtractor
        .new(file_content, intent, params[:generation_type], params[:user_instruction])
        .extract
    end

    def code_completion_task
      if code_completion_feature_setting&.self_hosted?
        CodeSuggestions::Tasks::SelfHostedCodeCompletion.new(
          feature_setting: code_completion_feature_setting,
          params: params,
          unsafe_passthrough_params: unsafe_passthrough_params
        )
      else
        CodeSuggestions::Tasks::CodeCompletion.new(
          params: params,
          unsafe_passthrough_params: unsafe_passthrough_params
        )
      end
    end

    def code_generation_task(instruction)
      if code_generation_feature_setting&.self_hosted?
        CodeSuggestions::Tasks::SelfHostedCodeGeneration.new(
          feature_setting: code_generation_feature_setting,
          params: params,
          unsafe_passthrough_params: unsafe_passthrough_params
        )
      else
        CodeSuggestions::Tasks::CodeGeneration.new(
          params: code_generation_params(instruction),
          unsafe_passthrough_params: unsafe_passthrough_params
        )
      end
    end

    def anthropic_model
      Feature.enabled?(:claude_3_code_generation_haiku, current_user) ? 'claude-3-haiku-20240307' : ANTHROPIC_MODEL
    end

    def language
      CodeSuggestions::ProgrammingLanguage.detect_from_filename(params.dig(:current_file, :file_name))
    end
    strong_memoize_attr(:language)

    def code_generation_params(instruction)
      params.merge(
        prefix: prefix,
        instruction: instruction,
        project: project,
        model_name: anthropic_model,
        current_user: current_user,
        skip_dependency_descriptions: Feature.enabled?(:code_suggestions_skip_dependency_descriptions, current_user)
      )
    end

    def project
      ::ProjectsFinder
        .new(
          params: { full_paths: [params[:project_path]] },
          current_user: current_user
        ).execute.first
    end
    strong_memoize_attr(:project)

    def code_generation_feature_setting
      ::Ai::FeatureSetting.find_by_feature(:code_generations)
    end

    def code_completion_feature_setting
      ::Ai::FeatureSetting.find_by_feature(:code_completions)
    end

    def trim_context!
      return if params[:context].blank?

      @params[:context] = Context.new(params[:context]).trimmed
    end
  end
end
