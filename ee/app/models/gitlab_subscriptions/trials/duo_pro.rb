# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoPro
      DURATION_NUMBER = 60
      DURATION = DURATION_NUMBER.days

      def self.eligible_namespace?(namespace_id, eligible_namespaces)
        return true if namespace_id.blank?

        namespace_id.to_i.in?(eligible_namespaces.pluck_primary_key)
      end
    end
  end
end
