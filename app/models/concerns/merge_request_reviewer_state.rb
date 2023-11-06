# frozen_string_literal: true

module MergeRequestReviewerState
  extend ActiveSupport::Concern

  included do
    enum state: {
      unreviewed: 0,
      reviewed: 1,
      requested_changes: 2
    }

    validates :state,
      presence: true,
      inclusion: { in: self.states.keys }
  end
end
