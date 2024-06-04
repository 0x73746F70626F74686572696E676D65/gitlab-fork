# frozen_string_literal: true

module ClickHouse
  module WriteBuffer
    BUFFER_KEY_PREFIX = 'clickhouse_write_buffer_'

    class << self
      def add(table_name, event_hash)
        Gitlab::Redis::SharedState.with do |redis|
          redis.rpush(buffer_key(table_name), event_hash.to_json)
        end
      end

      def pop(table_name, limit)
        Gitlab::Redis::SharedState.with do |redis|
          Array.wrap(redis.lpop(buffer_key(table_name), limit)).map do |hash|
            Gitlab::Json.parse(hash, symbolize_names: true)
          end
        end
      end

      private

      def buffer_key(table_name)
        "#{BUFFER_KEY_PREFIX}#{table_name}"
      end
    end
  end
end
