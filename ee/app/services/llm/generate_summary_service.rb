# frozen_string_literal: true

module Llm
  class GenerateSummaryService < BaseService
    SUPPORTED_ISSUABLE_TYPES = %w[issue work_item epic].freeze

    private

    def ai_action
      :summarize_comments
    end

    def perform
      schedule_completion_worker
    end

    def valid?
      super &&
        SUPPORTED_ISSUABLE_TYPES.include?(resource.to_ability_name) &&
        Ability.allowed?(user, :summarize_comments, resource)
    end

    def notes
      NotesFinder.new(user, target: resource).execute.by_humans
    end
  end
end
