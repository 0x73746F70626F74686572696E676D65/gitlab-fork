# frozen_string_literal: true

module Geo
  class EventWorker
    include ApplicationWorker
    include GeoQueue

    idempotent!
    data_consistency :sticky
    sidekiq_options retry: 3, dead: false
    loggable_arguments 0, 1, 2

    def perform(replicable_name, event_name, payload)
      Geo::EventService.new(replicable_name, event_name, payload).execute
    end
  end
end
