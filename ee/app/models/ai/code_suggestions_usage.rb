# frozen_string_literal: true

module Ai
  class CodeSuggestionsUsage < ClickHouseModel
    self.table_name = 'code_suggestion_usages'

    EVENTS = {
      'code_suggestions_requested' => 1, # old event name
      'code_suggestion_shown_in_ide' => 2,
      'code_suggestion_accepted_in_ide' => 3,
      'code_suggestion_rejected_in_ide' => 4,
      'code_suggestion_direct_access_token_refresh' => 5
    }.freeze

    attr_accessor :event, :user

    attribute :timestamp, :datetime, default: -> { DateTime.current }

    validates :event, inclusion: { in: EVENTS.keys }
    validates :user, presence: true
    validates :timestamp, presence: true

    def to_clickhouse_csv_row
      {
        event: EVENTS[event],
        timestamp: timestamp.to_f,
        user_id: user&.id
      }
    end
  end
end
