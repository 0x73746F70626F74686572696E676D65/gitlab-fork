# frozen_string_literal: true

module Resolvers
  module ComplianceManagement
    class FrameworkResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      authorize :read_compliance_framework

      type ::Types::ComplianceManagement::ComplianceFrameworkType.connection_type, null: true

      argument :id, ::Types::GlobalIDType[::ComplianceManagement::Framework],
        description: 'Global ID of a specific compliance framework to return.',
        required: false

      argument :search, GraphQL::Types::String,
        required: false,
        default_value: nil,
        description: 'Search framework with most similar names.'

      argument :ids, [::Types::GlobalIDType[::ComplianceManagement::Framework]],
        description: 'List of Global IDs of compliance frameworks to return.',
        required: false

      def resolve(id: nil, ids: nil, search: nil)
        ids = [id] if ids.nil? || id.present?
        model_ids = ids.map { |single_id| single_id&.model_id }

        BatchLoader::GraphQL
          .for(object.id)
          .batch(key: [:framework_id, model_ids], default_value: []) do |namespace_ids, loader|
          by_namespace_id = namespace_ids.index_with { |_namespace_id| model_ids }

          evaluate(namespace_ids, by_namespace_id, loader, search)
        end
      end

      private

      def evaluate(namespace_ids, by_namespace_id, loader, search)
        frameworks(namespace_ids, search).group_by(&:namespace_id).each do |ns_id, group|
          by_namespace_id[ns_id].each do |fw_id|
            group.each do |fw|
              next unless fw_id.nil? || fw_id.to_i == fw.id

              loader.call(ns_id) { |array| array << fw }
            end
          end
        end
      end

      def frameworks(namespace_ids, search)
        ::ComplianceManagement::Framework.with_namespaces(namespace_ids).search(search)
      end
    end
  end
end
