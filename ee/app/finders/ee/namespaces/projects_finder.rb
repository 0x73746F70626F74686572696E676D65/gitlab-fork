# frozen_string_literal: true

module EE
  # Namespaces::ProjectsFinder
  #
  # Extends Namespaces::ProjectsFinder
  #
  # Added arguments:
  #   params:
  #     has_vulnerabilities: boolean
  #     has_code_coverage: boolean
  #     sbom_component_id: integer
  #
  module Namespaces
    module ProjectsFinder
      extend ::Gitlab::Utils::Override

      private

      override :filter_projects
      def filter_projects(collection)
        collection = super(collection)
        collection = with_vulnerabilities(collection)
        collection = with_code_coverage(collection)
        collection = with_compliance_framework(collection)
        collection = by_negated_compliance_framework_filters(collection)
        collection = with_sbom_component_version(collection)
        by_compliance_framework_presence(collection)
      end

      def with_compliance_framework(collection)
        filter_id = params.dig(:compliance_framework_filters, :id)

        return collection if filter_id.nil?

        collection.compliance_framework_id_in(filter_id)
      end

      def by_negated_compliance_framework_filters(collection)
        filter_id = params.dig(:compliance_framework_filters, :not, :id)

        return collection if filter_id.nil?

        collection.compliance_framework_id_not_in(filter_id)
      end

      def by_compliance_framework_presence(collection)
        filter = params.dig(:compliance_framework_filters, :presence_filter)
        return collection if filter.nil?

        case filter.to_sym
        when :any
          collection.any_compliance_framework
        when :none
          collection.missing_compliance_framework
        else
          raise ArgumentError, "The presence filter is not supported: '#{filter}'"
        end
      end

      override :sort
      def sort(items)
        if params[:sort] == :excess_repo_storage_size_desc
          return items.order_by_excess_repo_storage_size_desc(namespace.actual_size_limit)
        end

        super(items)
      end

      def with_vulnerabilities(items)
        return items unless params[:has_vulnerabilities].present?

        items.has_vulnerabilities
      end

      def with_code_coverage(items)
        return items unless params[:has_code_coverage].present?

        items.with_coverage_feature_usage(default_branch: true)
      end

      def with_sbom_component_version(items)
        return items unless params[:sbom_component_id].present?

        items.with_sbom_component_version(params[:sbom_component_id].to_i)
      end
    end
  end
end
