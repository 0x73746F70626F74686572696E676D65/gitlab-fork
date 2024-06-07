# frozen_string_literal: true

module CodeSuggestions
  class Context
    MAX_BODY_SIZE = 500_000

    def initialize(context)
      @context = context
    end

    def trimmed
      return context if context.blank?

      sum = 0
      # find first N elements that fits into the body size
      last_idx = context.find_index do |item|
        sum += item[:content].size
        sum > MAX_BODY_SIZE
      end

      return context unless last_idx

      context.take(last_idx) # rubocop:disable CodeReuse/ActiveRecord -- context is an array
    end

    private

    attr_reader :context
  end
end
