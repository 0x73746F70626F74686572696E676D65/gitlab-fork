# frozen_string_literal: true

module CloudConnector
  class Access < ApplicationRecord
    self.table_name = 'cloud_connector_access'
    validates :data, json_schema: { filename: "cloud_connector_access" }
    validates :data, presence: true

    after_save :clear_available_services_cache!

    def clear_available_services_cache!
      ::CloudConnector::AvailableServices.clear_memoization(:available_services)
    end
  end
end
