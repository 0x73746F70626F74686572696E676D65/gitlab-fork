# frozen_string_literal: true

module Sbom
  class Source < ApplicationRecord
    include ::Sbom::SourceHelper

    enum source_type: {
      dependency_scanning: 0,
      container_scanning: 1,
      container_scanning_for_registry: 2
    }

    validates :source_type, presence: true
    validates :source, presence: true, json_schema: { filename: 'sbom_source' }

    alias_attribute :data, :source
  end
end
