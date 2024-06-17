# frozen_string_literal: true

# This class represents a software license policy. Which means the fact that the user
# approves or not of the use of a certain software license in their project.
# For use in the License Management feature.
class SoftwareLicensePolicy < ApplicationRecord
  include Presentable
  include EachBatch

  # Only allows modification of the approval status
  FORM_EDITABLE = %i[approval_status].freeze

  belongs_to :project, inverse_of: :software_license_policies
  belongs_to :software_license, -> { readonly }
  belongs_to :custom_software_license, class_name: 'Security::CustomSoftwareLicense'
  belongs_to :scan_result_policy_read,
    class_name: 'Security::ScanResultPolicyRead',
    foreign_key: 'scan_result_policy_id',
    optional: true

  attr_readonly :software_license, :custom_software_license

  enum classification: {
    denied: 0,
    allowed: 1
  }
  validates_presence_of :project
  validates :classification, presence: true

  validates :software_license, presence: true, unless: :custom_software_license
  validates :custom_software_license, presence: true, unless: :software_license

  # A license is unique for its project since it can't be approved and denied.
  validates :software_license, uniqueness: { scope: [:project_id, :scan_result_policy_id] }, allow_blank: true
  validates :custom_software_license, uniqueness: { scope: [:project_id, :scan_result_policy_id] }, allow_blank: true

  scope :ordered, -> { SoftwareLicensePolicy.includes(:software_license).order("software_licenses.name ASC") }
  scope :for_project, ->(project) { where(project: project) }
  scope :for_scan_result_policy_read, ->(scan_result_policy_id) { where(scan_result_policy_id: scan_result_policy_id) }
  scope :with_license, -> { joins(:software_license) }
  scope :including_license, -> { includes(:software_license) }
  scope :including_custom_license, -> { includes(:custom_software_license) }
  scope :including_scan_result_policy_read, -> { includes(:scan_result_policy_read) }
  scope :unreachable_limit, -> { limit(1_000) }
  scope :with_scan_result_policy_read, -> { where.not(scan_result_policy_id: nil) }

  scope :exclusion_allowed, -> do
    joins(:scan_result_policy_read)
      .where(scan_result_policy_read: { match_on_inclusion_license: false })
  end

  scope :with_license_by_name, ->(license_name) do
    with_license.where(SoftwareLicense.arel_table[:name].lower.in(Array(license_name).map(&:downcase)))
  end

  scope :by_spdx, ->(spdx_identifier) do
    with_license.where(software_licenses: { spdx_identifier: spdx_identifier })
  end

  delegate :spdx_identifier, to: :software_license

  def self.approval_status_values
    %w[allowed denied]
  end

  def approval_status
    classification
  end

  def name
    if Feature.enabled?(:custom_software_license, project)
      software_license&.name || custom_software_license&.name
    else
      software_license&.name
    end
  end
end
