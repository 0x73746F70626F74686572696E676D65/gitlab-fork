# frozen_string_literal: true

module Security
  class CustomSoftwareLicense < ApplicationRecord
    self.table_name = 'custom_software_licenses'

    belongs_to :project

    validates :name, presence: true, uniqueness: { scope: :project_id }, length: { maximum: 255 }
  end
end
