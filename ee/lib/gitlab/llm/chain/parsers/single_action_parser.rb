# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Parsers
        class SingleActionParser < OutputParser
          attr_reader :action, :action_input, :thought, :final_answer

          def parse
            return unless @output

            @parsed_thoughts = parse_json_objects

            return unless @parsed_thoughts.present?

            parse_final_answer
            parse_action
          end

          private

          def final_answer?
            @parsed_thoughts.first[:type] == 'final_answer_delta'
          end

          def parse_final_answer
            return unless final_answer?

            @final_answer = ''

            @parsed_thoughts.each do |t|
              @final_answer += t[:data][:text]
            end

            @final_answer
          end

          def parse_action
            response = @parsed_thoughts.first

            return unless response[:type] == 'action'

            @thought = response[:data][:thought]
            @action = response[:data][:tool].camelcase
            @action_input = response[:data][:tool_input]
          end

          def parse_json_objects
            json_strings = @output.split("\n")

            json_strings.map do |str|
              Gitlab::Json.parse(str).with_indifferent_access
            end
          end
        end
      end
    end
  end
end
