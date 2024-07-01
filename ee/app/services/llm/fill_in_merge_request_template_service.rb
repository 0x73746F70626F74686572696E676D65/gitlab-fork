# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts -- TODO file to be removed
module Llm
  class FillInMergeRequestTemplateService < BaseService
    extend ::Gitlab::Utils::Override

    override :valid
    def valid?
      false
    end

    private

    def ai_action
      :fill_in_merge_request_template
    end

    def perform
      schedule_completion_worker
    end
  end
end
# rubocop:enable Gitlab/BoundedContexts
