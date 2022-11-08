# frozen_string_literal: true

module RuboCop
  module Cop
    module Gitlab
      class Json < RuboCop::Cop::Base
        extend RuboCop::Cop::AutoCorrector

        MSG = <<~EOL
          Prefer `Gitlab::Json` over calling `JSON` or `to_json` directly. See https://docs.gitlab.com/ee/development/json.html
        EOL

        AVAILABLE_METHODS = %i[parse parse! load decode dump generate encode pretty_generate].to_set.freeze

        def_node_matcher :json_node?, <<~PATTERN
          (send (const {nil? | (const nil? :ActiveSupport)} :JSON) $_ $...)
        PATTERN

        def_node_matcher :to_json_call?, <<~PATTERN
          (send $_ :to_json)
        PATTERN

        def on_send(node)
          method_name, arg_source = match_node(node)
          return unless method_name

          add_offense(node) do |corrector|
            replacement = "#{cbased(node)}Gitlab::Json.#{method_name}(#{arg_source})"

            corrector.replace(node.source_range, replacement)
          end
        end

        private

        def match_node(node)
          method_name, arg_nodes = json_node?(node)

          # Only match if the method is implemented by Gitlab::Json
          if method_name && AVAILABLE_METHODS.include?(method_name)
            return [method_name, arg_nodes.map(&:source).join(", ")]
          end

          receiver = to_json_call?(node)
          return [:dump, receiver.source] if receiver

          nil
        end

        def cbased(node)
          return unless %r{/ee/}.match?(node.location.expression.source_buffer.name)

          "::"
        end
      end
    end
  end
end
