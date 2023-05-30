# frozen_string_literal: true

module Llm
  class GenerateSummaryService < BaseService
    SUPPORTED_ISSUABLE_TYPES = %w[issue epic].freeze

    private

    def perform
      worker_perform(user, resource, :summarize_comments, options)
    end

    def valid?
      super &&
        SUPPORTED_ISSUABLE_TYPES.include?(resource.to_ability_name) &&
        Ability.allowed?(user, :summarize_notes, resource) &&
        !notes.empty?
    end

    def notes
      NotesFinder.new(user, target: resource).execute.by_humans
    end
  end
end
