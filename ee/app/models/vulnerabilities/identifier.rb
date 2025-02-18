# frozen_string_literal: true

module Vulnerabilities
  class Identifier < ApplicationRecord
    include EachBatch
    include ShaAttribute

    self.table_name = "vulnerability_identifiers"

    sha_attribute :fingerprint

    has_many :finding_identifiers, class_name: 'Vulnerabilities::FindingIdentifier', inverse_of: :identifier, foreign_key: 'identifier_id'
    has_many :findings, through: :finding_identifiers, class_name: 'Vulnerabilities::Finding'

    has_many :primary_findings, class_name: 'Vulnerabilities::Finding', inverse_of: :primary_identifier, foreign_key: 'primary_identifier_id'

    belongs_to :project

    validates :project, presence: true
    validates :external_type, presence: true
    validates :external_id, presence: true
    validates :fingerprint, presence: true
    # Uniqueness validation doesn't work with binary columns, so save this useless query. It is enforce by DB constraint anyway.
    # TODO: find out why it fails
    # validates :fingerprint, presence: true, uniqueness: { scope: :project_id }
    validates :name, presence: true
    validates :url, url: { schemes: %w[http https ftp], allow_nil: true }

    scope :by_projects, ->(values) { where(project_id: values) }
    scope :with_fingerprint, ->(fingerprints) { where(fingerprint: fingerprints) }
    scope :with_external_type, ->(external_type) { where('LOWER(external_type) = LOWER(?)', external_type) }
    scope :select_primary_finding_vulnerability_ids, -> {
      joins(:primary_findings).select('vulnerability_occurrences.vulnerability_id AS vulnerability_id')
    }

    def cve?
      external_type.casecmp?('cve')
    end

    def cwe?
      external_type.casecmp?('cwe')
    end

    def other?
      !(cve? || cwe?)
    end

    # This is included at the bottom of the model definition because
    # BulkInsertSafe complains about the autosave callbacks generated
    # for the `has_many` associations otherwise.
    include BulkInsertSafe
  end
end
