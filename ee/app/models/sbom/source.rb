# frozen_string_literal: true

module Sbom
  class Source < ApplicationRecord
    enum source_type: {
      dependency_scanning: 0,
      container_scanning: 1
    }

    validates :source_type, presence: true
    validates :source, presence: true, json_schema: { filename: 'sbom_source' }

    scope :filter_by_package_managers, ->(package_managers) do
      where("source->'package_manager'->>'name' IN (?)", package_managers)
    end

    def self.get_ids_filtered_by_package_managers(package_managers)
      filter_by_package_managers(package_managers).pluck(:id)
    end

    def packager
      source.dig('package_manager', 'name')
    end

    def input_file_path
      source.dig('input_file', 'path')
    end
  end
end
