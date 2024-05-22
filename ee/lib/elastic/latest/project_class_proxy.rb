# frozen_string_literal: true

module Elastic
  module Latest
    class ProjectClassProxy < ApplicationClassProxy
      extend ::Gitlab::Utils::Override

      def elastic_search(query, options: {})
        options[:in] = %w[name^10 name_with_namespace^2 path_with_namespace path^9 description]
        options[:project_id_field] = :id
        options[:no_join_project] = true

        query_hash = basic_query_hash(options[:in], query, options)

        filters = [{ terms: { _name: context.name(:doc, :is_a, es_type), type: [es_type] } }]

        context.name(:project) do
          if options[:namespace_id]
            filters << {
              terms: {
                _name: context.name(:related, :namespaces),
                namespace_id: [options[:namespace_id]].flatten
              }
            }
          end

          unless options[:include_archived]
            filters << {
              terms: {
                _name: context.name(:archived, false),
                archived: [false]
              }
            }
          end

          if options[:visibility_levels]
            filters << {
              terms: {
                _name: context.name(:visibility_level),
                visibility_level: [options[:visibility_levels]].flatten
              }
            }
          end

          if options[:project_ids]
            namespace = namespace_for_traversal_ids_filter(options)

            if namespace.present?
              prefix_filter = prefix_traversal_id_query(namespace, options)

              filters << prefix_filter unless prefix_filter == {}
              must_not = rejected_project_filter(namespace, options)
            else
              filters << {
                bool: project_ids_query(options[:current_user], options[:project_ids], options[:public_and_internal_projects], no_join_project: options[:no_join_project], project_id_field: options[:project_id_field])
              }
            end
          end

          query_hash[:query][:bool][:filter] ||= []
          query_hash[:query][:bool][:filter] += filters
          query_hash[:query][:bool][:must_not] = must_not if must_not
        end

        search(query_hash, options)
      end

      def namespace_for_traversal_ids_filter(options)
        return unless options[:group_id]
        return unless traversal_ids_flag_enabled?(options)
        return if should_use_project_ids_filter?(options)

        group = Group.find(options[:group_id])
        group if options[:current_user].authorized_groups.include?(group)
      end

      def traversal_ids_flag_enabled?(options)
        options[:current_user] &&
          Feature.enabled?(:advanced_search_project_traversal_ids_query, options[:current_user], type: :gitlab_com_derisk)
      end

      def prefix_traversal_id_query(namespace, options)
        ancestry_filter(options[:current_user], [namespace.elastic_namespace_ancestry], prefix: :traversal_ids)
      end

      def rejected_project_filter(namespace, options)
        current_user = options[:current_user]
        scoped_project_ids = scoped_project_ids(current_user, options[:project_ids])

        return if scoped_project_ids == :any

        project_ids = Project
                        .id_in(scoped_project_ids)
                        .public_or_visible_to_user(current_user)
                        .pluck_primary_key

        rejected_ids = namespace.all_project_ids_except(project_ids).pluck_primary_key

        return unless rejected_ids.any?

        {
          terms: {
            id: rejected_ids
          }
        }
      end

      override :routing_options
      def routing_options(options)
        return super unless ::Elastic::DataMigrationService.migration_has_finished?(:reindex_projects_to_apply_routing)

        group = Group.find_by_id(options[:group_id])

        return {} unless group

        root_namespace_id = group.root_ancestor.id

        { routing: "n_#{root_namespace_id}" }
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def preload_indexing_data(relation)
        relation.includes(:project_feature, :route, :catalog_resource, :fork_network, :mirror_user, :repository_languages, :group, namespace: :owner)
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
