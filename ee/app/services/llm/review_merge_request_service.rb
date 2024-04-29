# frozen_string_literal: true

module Llm
  class ReviewMergeRequestService < ::Llm::BaseService
    private

    def ai_action
      :review_merge_request
    end

    def perform
      schedule_completion_worker
    end

    def valid?
      super && resource.ai_review_merge_request_allowed?(user)
    end
  end
end
