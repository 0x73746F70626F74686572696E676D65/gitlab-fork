# frozen_string_literal: true

module Gitlab
  module Elastic
    BoolExpr = Struct.new(:must, :must_not, :should, :filter, :minimum_should_match) do # rubocop:disable Lint/StructNewOverride -- existing implementation
      def initialize
        super
        reset!
      end

      def reset!
        self.must     = []
        self.must_not = []
        self.should   = []
        self.filter   = []
        self.minimum_should_match = nil
      end

      def to_h
        super.reject { |_, value| value.blank? }
      end

      def to_json(...)
        to_h.to_json(...)
      end

      def eql?(other)
        to_h.eql?(other.to_h)
      end
    end
  end
end
