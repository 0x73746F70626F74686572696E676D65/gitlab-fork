# frozen_string_literal: true

module Gitlab
  module Llm
    class CompletionsFactory
      def self.completion!(prompt_message, options = {})
        features_list = ::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST
        name = prompt_message.ai_action.to_sym
        raise NameError, "completion class for action #{name} not found" unless features_list.key?(name)

        service_class, prompt_class = features_list[name].values_at(:service_class, :prompt_class)
        service_class.new(prompt_message, prompt_class, options.merge(action: name))
      end
    end
  end
end

::Gitlab::Llm::CompletionsFactory.prepend_mod
