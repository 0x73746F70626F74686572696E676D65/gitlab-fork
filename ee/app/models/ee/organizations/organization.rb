# frozen_string_literal: true

module EE
  module Organizations
    module Organization
      extend ActiveSupport::Concern

      prepended do
        has_many :active_projects,
          -> { non_archived },
          class_name: 'Project',
          inverse_of: :organization
        has_many :sbom_occurrences, through: :active_projects, class_name: 'Sbom::Occurrence'
        has_many :vulnerability_exports, class_name: 'Vulnerabilities::Export'
      end
    end
  end
end
