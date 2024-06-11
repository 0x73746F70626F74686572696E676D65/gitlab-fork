# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      class SlashCommand
        VS_CODE = 'vscode'
        WEB_IDE = 'webide'
        WEB = 'web'
        IDE_SOURCES = [VS_CODE, WEB_IDE].freeze

        def self.for(message:, tools: [])
          command, user_input = message.slash_command_and_input
          return unless command

          tool = tools.find do |tool|
            next unless tool::Executor.respond_to?(:slash_commands)

            tool::Executor.slash_commands.has_key?(command)
          end

          return unless tool

          command_options = tool::Executor.slash_commands[command]

          client_source = client_source(message)
          new(name: command, user_input: user_input, tool: tool, command_options: command_options,
            client_source: client_source)
        end

        def self.client_source(message)
          if message.user_agent&.match?(Gitlab::Regex.vs_code_user_agent_regex)
            VS_CODE
          elsif web_ide?(message)
            WEB_IDE
          else
            WEB
          end
        end

        def self.web_ide?(message)
          url = message.referer_url
          return if url.blank? || !url.start_with?(Gitlab.config.gitlab.base_url)

          route = Rails.application.routes.recognize_path(message.referer_url)
          route[:controller] == 'ide'
        end

        attr_reader :name, :user_input, :tool, :client_source

        def initialize(name:, user_input:, tool:, command_options:, client_source: nil)
          @name = name
          @user_input = user_input
          @tool = tool
          @instruction = command_options[:instruction]
          @instruction_with_input = command_options[:instruction_with_input]
          @client_source = client_source
        end

        def prompt_options
          {
            input: instruction
          }
        end

        private

        def instruction
          return @instruction if user_input.blank? || @instruction_with_input.blank?

          format(@instruction_with_input, input: user_input)
        end
      end
    end
  end
end
