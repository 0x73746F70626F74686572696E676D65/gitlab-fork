# frozen_string_literal: true

module Sbom
  class Occurrence < ApplicationRecord
    LICENSE_COLUMNS = [:spdx_identifier, :name, :url].freeze
    include EachBatch
    include IgnorableColumns

    belongs_to :component, optional: false
    belongs_to :source_package
    belongs_to :component_version
    belongs_to :project, optional: false
    belongs_to :pipeline, class_name: 'Ci::Pipeline'
    belongs_to :source
    belongs_to :source_package, optional: true

    has_many :occurrences_vulnerabilities,
      class_name: 'Sbom::OccurrencesVulnerability',
      foreign_key: :sbom_occurrence_id,
      inverse_of: :occurrence

    has_many :vulnerabilities, through: :occurrences_vulnerabilities

    enum highest_severity: ::Enums::Vulnerability.severity_levels

    validates :commit_sha, presence: true
    validates :uuid, presence: true, uniqueness: { case_sensitive: false }
    validates :package_manager, length: { maximum: 255 }
    validates :component_name, length: { maximum: 255 }
    validates :input_file_path, length: { maximum: 1024 }
    validates :licenses, json_schema: { filename: 'sbom_occurrences-licenses' }

    delegate :name, to: :component
    delegate :purl_type, to: :component
    delegate :component_type, to: :component
    delegate :version, to: :component_version, allow_nil: true
    delegate :source_package_name, to: :component_version, allow_nil: true

    alias_attribute :packager, :package_manager

    scope :order_by_id, -> { order(id: :asc) }

    scope :order_by_component_name, ->(direction) do
      order(component_name: direction)
    end

    scope :order_by_package_name, ->(direction) do
      order(package_manager: direction, component_name: :asc)
    end

    scope :order_by_spdx_identifier, ->(direction, depth: 1) do
      order(Gitlab::Pagination::Keyset::Order.build(
        0.upto(depth).map do |index|
          sql = Arel.sql("(licenses#>'{#{index},spdx_identifier}')::text")
          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: "spdx_identifier_#{index}",
            order_expression: direction == "desc" ? sql.desc : sql.asc,
            sql_type: 'text'
          )
        end
      ))
    end

    scope :by_licenses, ->(licenses, depth: 1) do
      unknown, ids = licenses.partition { |id| id.casecmp?("unknown") }

      id_filters = (0..depth).map do |index|
        "(licenses#>'{#{index},spdx_identifier}' ?| array[:licenses])"
      end

      query_parts = []
      query_parts.append(*id_filters) if ids.present?
      query_parts.append("licenses = '[]'") if unknown.present?

      return none unless query_parts.present?

      where(query_parts.join(' OR '), licenses: Array(ids))
    end

    scope :unarchived, -> { where(archived: false) }
    scope :by_project_ids, ->(project_ids) { where(project_id: project_ids) }
    scope :by_uuids, ->(uuids) { where(uuid: uuids) }
    scope :for_namespace_and_descendants, ->(namespace) do
      where("traversal_ids >= ('{?}')", namespace.traversal_ids)
        .where("traversal_ids < ('{?}')", namespace.next_traversal_ids)
    end

    scope :filter_by_package_managers, ->(package_managers) do
      where(package_manager: package_managers)
    end

    scope :filter_by_components, ->(components) do
      where(component: components)
    end

    scope :filter_by_source_packages, ->(source_packages) do
      where(source_package: source_packages)
    end

    scope :filter_by_component_names, ->(component_names) do
      where(component_name: component_names)
    end

    scope :filter_by_source_types, ->(source_types) do
      left_outer_joins(:source).where(sbom_sources: { source_type: source_types })
    end

    scope :filter_by_search_with_component_and_group, ->(search, component_id, group) do
      relation = includes(project: :namespace).where(component_version_id: component_id, project: group.all_projects)
      if search.present?
        relation.where('input_file_path ILIKE ?', "%#{sanitize_sql_like(search.to_s)}%") # rubocop:disable GitlabSecurity/SqlInjection -- This cop is a false positive as we are using parameterization via ?
      else
        relation
      end
    end

    scope :with_component, -> { includes(:component) }
    scope :with_licenses, -> do
      columns = LICENSE_COLUMNS.map { |column| "#{column} TEXT" }.join(", ")
      sbom_licenses = Arel.sql(<<~SQL.squish)
      LEFT JOIN LATERAL jsonb_to_recordset(sbom_occurrences.licenses) AS sbom_licenses(#{columns}) ON TRUE
      SQL
      joins(sbom_licenses)
        .where("licenses != '[]'")
        .where.not(sbom_licenses: { spdx_identifier: nil })
    end
    scope :with_project_route, -> { includes(project: :route).allow_cross_joins_across_databases(url: "https://gitlab.com/gitlab-org/gitlab/-/issues/420046") }
    scope :with_project_namespace, -> { includes(project: [namespace: :route]) }
    scope :with_source, -> { includes(:source) }
    scope :with_version, -> { includes(:component_version) }
    scope :with_pipeline_project_and_namespace, -> { preload(pipeline: { project: :namespace }) }
    scope :with_vulnerabilities, -> { preload(:vulnerabilities) }
    scope :with_component_source_version_and_project, -> do
      includes(:component, :source, :component_version, :project)
    end
    scope :filter_by_non_nil_component_version, -> { where.not(component_version: nil) }

    scope :order_by_severity, ->(direction) do
      order(highest_severity_arel_nodes(direction))
    end

    scope :visible_to, ->(user) do
      return self if user.can_read_all_resources?

      joins(project: [:project_authorizations])
        .where(project_authorizations: { user_id: user.id })
    end

    def location
      {
        blob_path: input_file_blob_path,
        path: input_file_path,
        top_level: false,
        ancestors: ancestors
      }
    end

    private

    def input_file_blob_path
      return unless input_file_path.present?

      Gitlab::Routing.url_helpers.project_blob_path(project, File.join(commit_sha, input_file_path))
    end

    def self.highest_severity_arel_nodes(direction)
      return Sbom::Occurrence.arel_table[:highest_severity].asc.nulls_first if direction == 'asc'

      Sbom::Occurrence.arel_table[:highest_severity].desc.nulls_last
    end
  end
end
