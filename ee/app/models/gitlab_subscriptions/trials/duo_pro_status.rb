# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class DuoProStatus
      def initialize(add_on_purchase:)
        @add_on_purchase = add_on_purchase
      end

      def show?
        add_on_purchase.present? && active?
      end

      private

      attr_reader :add_on_purchase

      def active?
        Date.current <= add_on_purchase.expires_on
      end
    end
  end
end
