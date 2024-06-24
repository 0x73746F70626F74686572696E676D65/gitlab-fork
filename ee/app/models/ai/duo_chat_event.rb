# frozen_string_literal: true

module Ai
  class DuoChatEvent < ClickHouseModel
    self.table_name = 'duo_chat_events'

    EVENTS = {
      'request_duo_chat_response' => 1
    }.freeze

    attribute :user
    attribute :event, :string
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
