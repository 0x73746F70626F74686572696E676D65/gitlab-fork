# frozen_string_literal: true

module Geo
  class SyncWorker
    include ApplicationWorker
    include GeoQueue

    idempotent!
    data_consistency :sticky
    sidekiq_options retry: false, dead: false
    loggable_arguments 0, 1

    def perform(replicable_name, model_record_id)
      Geo::SyncService.new(replicable_name, model_record_id).execute
    end
  end
end
