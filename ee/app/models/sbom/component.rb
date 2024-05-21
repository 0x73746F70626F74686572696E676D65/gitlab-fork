# frozen_string_literal: true

module Sbom
  class Component < ApplicationRecord
    include IgnorableColumns

    ignore_column :source_package_name, remove_with: '17.3', remove_after: '2024-07-15'

    enum component_type: ::Enums::Sbom.component_types
    enum purl_type: ::Enums::Sbom.purl_types

    validates :component_type, presence: true
    validates :name, presence: true, length: { maximum: 255 }

    scope :libraries, -> { where(component_type: :library) }
    scope :by_purl_type_and_name, ->(purl_type, name) do
      where(name: name, purl_type: purl_type)
    end
  end
end
