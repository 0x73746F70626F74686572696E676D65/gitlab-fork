# frozen_string_literal: true

module Vulnerabilities
  class Read < ApplicationRecord
    include VulnerabilityScopes
    include EachBatch
    include UnnestedInFilters::Dsl
    include FromUnion

    declarative_enum DismissalReasonEnum

    SEVERITY_COUNT_LIMIT = 1001

    self.table_name = "vulnerability_reads"
    self.primary_key = :vulnerability_id

    belongs_to :vulnerability, inverse_of: :vulnerability_read
    belongs_to :project
    belongs_to :scanner, class_name: 'Vulnerabilities::Scanner'

    validates :vulnerability_id, uniqueness: true, presence: true
    validates :project_id, presence: true
    validates :scanner_id, presence: true
    validates :report_type, presence: true
    validates :severity, presence: true
    validates :state, presence: true
    validates :uuid, uniqueness: { case_sensitive: false }, presence: true

    validates :location_image, length: { maximum: 2048 }
    validates :has_issues, inclusion: { in: [true, false], message: N_('must be a boolean value') }
    validates :has_merge_request, inclusion: { in: [true, false], message: N_('must be a boolean value') }
    validates :resolved_on_default_branch, inclusion: { in: [true, false], message: N_('must be a boolean value') }
    validates :has_remediations, inclusion: { in: [true, false], message: N_('must be a boolean value') }

    enum state: ::Enums::Vulnerability.vulnerability_states
    enum report_type: ::Enums::Vulnerability.report_types
    enum severity: ::Enums::Vulnerability.severity_levels, _prefix: :severity
    enum owasp_top_10: ::Enums::Vulnerability.owasp_top_10

    scope :by_uuid, ->(uuids) { where(uuid: uuids) }
    scope :by_vulnerabilities, ->(vulnerabilities) { where(vulnerability: vulnerabilities) }

    scope :order_severity_asc, -> { reorder(severity: :asc, vulnerability_id: :desc) }
    scope :order_severity_desc, -> { reorder(severity: :desc, vulnerability_id: :desc) }
    scope :order_detected_at_asc, -> { reorder(vulnerability_id: :asc) }
    scope :order_detected_at_desc, -> { reorder(vulnerability_id: :desc) }

    scope :order_severity_asc_traversal_ids_asc, -> { reorder(severity: :asc, traversal_ids: :asc, vulnerability_id: :asc) }
    scope :order_severity_desc_traversal_ids_desc, -> { reorder(severity: :desc, traversal_ids: :desc, vulnerability_id: :desc) }

    scope :by_group, ->(group) { traversal_ids_gteq(group.traversal_ids).traversal_ids_lt(group.next_traversal_ids) }
    scope :traversal_ids_gteq, ->(traversal_ids) { where(arel_table[:traversal_ids].gteq(traversal_ids)) }
    scope :traversal_ids_lt, ->(traversal_ids) { where(arel_table[:traversal_ids].lt(traversal_ids)) }
    scope :unarchived, -> { where(archived: false) }
    scope :order_traversal_ids_asc, -> do
      reorder(Gitlab::Pagination::Keyset::Order.build([
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'traversal_ids',
          order_expression: arel_table[:traversal_ids].asc,
          nullable: :not_nullable
        ),
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'vulnerability_id',
          order_expression: arel_table[:vulnerability_id].asc
        )
      ]))
    end
    scope :by_projects, ->(values) { where(project_id: values) }
    scope :by_scanner, ->(scanner) { where(scanner: scanner) }
    scope :by_scanner_ids, ->(scanner_ids) { where(scanner_id: scanner_ids) }
    scope :grouped_by_severity, -> { reorder(severity: :desc).group(:severity) }
    scope :with_report_types, ->(report_types) { where(report_type: report_types) }
    scope :with_severities, ->(severities) { where(severity: severities) }
    scope :with_states, ->(states) { where(state: states) }
    scope :with_owasp_top_10, ->(owasp_top_10) { where(owasp_top_10: owasp_top_10) }
    scope :with_container_image, ->(images) { where(location_image: images) }
    scope :with_container_image_starting_with, ->(image) { where(arel_table[:location_image].matches("#{image}%")) }
    scope :with_cluster_agent_ids, ->(agent_ids) { where(cluster_agent_id: agent_ids) }
    scope :with_resolution, ->(has_resolution = true) { where(resolved_on_default_branch: has_resolution) }
    scope :with_issues, ->(has_issues = true) { where(has_issues: has_issues) }
    scope :with_merge_request, ->(has_merge_request = true) { where(has_merge_request: has_merge_request) }
    scope :with_remediations, ->(has_remediations = true) { where(has_remediations: has_remediations) }
    scope :with_scanner_external_ids, ->(scanner_external_ids) { joins(:scanner).merge(::Vulnerabilities::Scanner.with_external_id(scanner_external_ids)) }
    scope :with_findings_scanner_and_identifiers, -> { includes(vulnerability: { findings: [:scanner, :identifiers, { finding_identifiers: :identifier }] }) }
    scope :resolved_on_default_branch, -> { where('resolved_on_default_branch IS TRUE') }
    scope :with_dismissal_reason, ->(dismissal_reason) { where(dismissal_reason: dismissal_reason) }
    scope :with_export_entities, -> do
      preload(
        vulnerability: [
          :group,
          { project: [:route],
            notes: [:updated_by, :author],
            findings: [:scanner, :identifiers] }
        ]
      )
    end

    scope :as_vulnerabilities, -> do
      preload(vulnerability: { project: [:route] }).current_scope.tap do |relation|
        relation.define_singleton_method(:records) do
          super().map(&:vulnerability)
        end
      end
    end

    scope :by_group_using_nested_loop, ->(group) do
      where(traversal_ids: all_vulnerable_traversal_ids_for(group))
    end

    def self.all_vulnerable_traversal_ids_for(group)
      by_group(group).unarchived.loose_index_scan(column: :traversal_ids)
    end

    def self.count_by_severity
      grouped_by_severity.count
    end

    def self.capped_count_by_severity
      # Return early when called by `Vulnerabilities::Read.none`.
      return {} if current_scope.is_a?(ActiveRecord::NullRelation)

      # Handles case when called directly `Vulnerabilities::Read.capped_count_by_severity`.
      if current_scope.nil?
        severities_to_iterate = severities.keys
        local_scope = self
      else
        severities_to_iterate = Array(current_scope.where_values_hash['severity'].presence || severities.keys)
        local_scope = current_scope.unscope(where: :severity)
      end

      array_severities_limit = severities_to_iterate.map do |severity|
        local_scope.with_severities(severity).select(:id, :severity).limit(SEVERITY_COUNT_LIMIT)
      end

      unscoped.from_union(array_severities_limit).count_by_severity
    end

    def self.order_by(method)
      case method.to_s
      when 'severity_desc' then order_severity_desc
      when 'severity_asc' then order_severity_asc
      when 'detected_desc' then order_detected_at_desc
      when 'detected_asc' then order_detected_at_asc
      else
        order_severity_desc
      end
    end

    def self.order_by_params_and_traversal_ids(method)
      case method.to_s
      when 'severity_desc' then order_severity_desc_traversal_ids_desc
      when 'severity_asc' then order_severity_asc_traversal_ids_asc
      when 'detected_desc' then order_detected_at_desc
      when 'detected_asc' then order_detected_at_asc
      else
        order_severity_desc_traversal_ids_desc
      end
    end

    def self.container_images
      # This method should be used only with pagination. When used without a specific limit, it might try to process an
      # unreasonable amount of records leading to a statement timeout.

      # We are enforcing keyset order here to make sure `primary_key` will not be automatically applied when returning
      # `ordered_items` from Gitlab::Graphql::Pagination::Keyset::Connection in GraphQL API. `distinct` option must be
      # set to true in `Gitlab::Pagination::Keyset::ColumnOrderDefinition` to return the collection in proper order.

      keyset_order = Gitlab::Pagination::Keyset::Order.build(
        [
          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: :location_image,
            column_expression: arel_table[:location_image],
            order_expression: arel_table[:location_image].asc
          )
        ])

      where(report_type: [:container_scanning, :cluster_image_scanning])
        .where.not(location_image: nil)
        .reorder(keyset_order)
        .select(:location_image)
        .distinct
    end

    def self.fetch_uuids
      pluck(:uuid)
    end
  end
end
