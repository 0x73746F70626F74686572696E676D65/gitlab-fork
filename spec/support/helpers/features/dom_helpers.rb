# frozen_string_literal: true

module Features
  module DomHelpers
    def has_testid?(testid, context: page, **kwargs)
      context.has_selector?("[data-testid='#{testid}']", **kwargs)
    end

    def find_by_testid(testid, context: page, **kwargs)
      context.find("[data-testid='#{testid}']", **kwargs)
    end

    def within_testid(testid, context: page, **kwargs, &block)
      context.within("[data-testid='#{testid}']", **kwargs, &block)
    end
  end
end
