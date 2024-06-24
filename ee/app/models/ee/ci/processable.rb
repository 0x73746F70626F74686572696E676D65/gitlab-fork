# frozen_string_literal: true

module EE
  module Ci
    module Processable
      def set_execution_policy_job!
        self.options = options.merge(execution_policy_job: true)
      end

      def execution_policy_job?
        !!options[:execution_policy_job]
      end
    end
  end
end
