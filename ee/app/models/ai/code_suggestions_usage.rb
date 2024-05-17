# frozen_string_literal: true

module Ai
  class CodeSuggestionsUsage < ClickHouseModel
    self.table_name = 'code_suggestions_usages'

    EVENTS = {
      'code_suggestions_requested' => 1,
      'code_suggestions_shown' => 2,
      'code_suggestions_accepted' => 3,
      'code_suggestions_rejected' => 4
    }.freeze

    attr_accessor :event, :user

    attribute :timestamp, :datetime, default: -> { DateTime.current }

    validates :event, inclusion: { in: EVENTS.keys }
    validates :user, presence: true
    validates :timestamp, presence: true

    def store
      return false unless valid?

      ::ClickHouse::WriteBuffer.write_event(to_clickhouse_csv_row)
    end

    def to_clickhouse_csv_row
      {
        event: EVENTS[event],
        timestamp: timestamp.to_f,
        user_id: user&.id
      }
    end
  end
end
