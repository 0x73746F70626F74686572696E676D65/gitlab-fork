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
        by_storage(collection)
      end

      def with_compliance_framework(collection)
        return collection if params[:compliance_framework_filters].nil?

        filter_id = params.dig(:compliance_framework_filters, :id)

        if filter_id.present?
          collection.compliance_framework_id_in(filter_id)
        else
          collection
        end
      end

      def by_storage(items)
        return items if params[:sort] != :storage

        items.order_by_total_repository_size_excess_desc(namespace.actual_size_limit)
      end

      def with_vulnerabilities(items)
        return items unless params[:has_vulnerabilities].present?

        items.has_vulnerabilities
      end

      def with_code_coverage(items)
        return items unless params[:has_code_coverage].present?

        items.with_coverage_feature_usage(default_branch: true)
      end
    end
  end
end
