# frozen_string_literal: true

module EE
  module Groups
    module TransferService
      extend ::Gitlab::Utils::Override

      PROJECT_QUERY_BATCH_SIZE = 1000

      override :ensure_allowed_transfer
      def ensure_allowed_transfer
        super

        raise_transfer_error(:saml_provider_or_scim_token_present) if saml_provider_or_scim_token_present?
      end

      override :localized_error_messages
      def localized_error_messages
        { saml_provider_or_scim_token_present:
          s_('TransferGroup|SAML Provider or SCIM Token is configured for this group.') }
          .merge(super).freeze
      end

      private

      override :add_owner_on_transferred_group
      def add_owner_on_transferred_group
        return super unless ::Namespaces::FreeUserCap::Enforcement.new(group).enforce_cap?

        ::Members::Groups::CreatorService.add_member(group, current_user, :owner, ignore_user_limits: true)
      end

      def saml_provider_or_scim_token_present?
        group.saml_provider.present? || group.scim_oauth_access_token.present?
      end

      override :post_update_hooks
      def post_update_hooks(updated_project_ids, old_root_ancestor_id)
        super

        # When a group is moved to a new group, there is no way to know whether the group was using Elasticsearch
        # before the transfer. If Elasticsearch limit indexing is enabled, the group has the ES cache invalidated.
        elasticsearch_limit_indexing_enabled = ::Gitlab::CurrentSettings.elasticsearch_limit_indexing?
        group.invalidate_elasticsearch_indexes_cache! if elasticsearch_limit_indexing_enabled
        zoekt_enabled = License.feature_available?(:zoekt_code_search) &&
          ::Gitlab::CurrentSettings.zoekt_indexing_enabled?

        # If zoekt is not enabled then we must not do db query as we will skip all zoekt related steps
        old_namespace_had_zoekt_enabled = ::Namespace.find_by_id(old_root_ancestor_id)&.use_zoekt? if zoekt_enabled

        group.all_projects.each_batch(of: PROJECT_QUERY_BATCH_SIZE) do |projects|
          projects.each.with_index do |project, idx|
            if zoekt_enabled && old_root_ancestor_id != project.root_namespace.id
              process_zoekt_project(old_root_ancestor_id, old_namespace_had_zoekt_enabled,
                project, idx)
            end

            process_elasticsearch_project(project, elasticsearch_limit_indexing_enabled)
          end
        end

        process_wikis(group)

        process_group_associations(old_root_ancestor_id, group) # Epics and WorkItems
      end

      def update_project_settings(updated_project_ids)
        ::ProjectSetting.for_projects(updated_project_ids).update_all(legacy_open_source_license_available: false)
      end

      def process_zoekt_project(old_root_ancestor_id, old_namespace_had_zoekt_enabled, project, idx)
        if old_namespace_had_zoekt_enabled
          interval_for_delete_worker = idx % ::Search::Zoekt::DeleteProjectWorker::MAX_JOBS_PER_HOUR
          ::Search::Zoekt.delete_in(interval_for_delete_worker, project.id, root_namespace_id: old_root_ancestor_id)
        end

        interval_for_indexer_worker = idx % ::Zoekt::IndexerWorker::MAX_JOBS_PER_HOUR
        ::Search::Zoekt.index_in(interval_for_indexer_worker, project.id) if project.use_zoekt?
      end

      def process_elasticsearch_project(project, elasticsearch_limit_indexing_enabled)
        # When a group is moved to a new group, there is no way to know whether the group was using Elasticsearch
        # before the transfer. If Elasticsearch limit indexing is enabled, each project has the ES cache invalidated.
        project.invalidate_elasticsearch_indexes_cache! if elasticsearch_limit_indexing_enabled
        # Reindex all projects and associated data to make sure the namespace_ancestry field gets
        # updated in each document.
        ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project) if project.maintaining_elasticsearch?
      end

      def process_group_associations(old_root_ancestor_id, group)
        return unless group.use_elasticsearch?

        if group.licensed_feature_available?(:epics)
          group.self_and_descendants.each_batch do |group_batch|
            ::Epic.in_selected_groups(group_batch).each_batch do |epics|
              ::Elastic::ProcessInitialBookkeepingService.track!(*epics)
            end
          end
        end

        return if old_root_ancestor_id == group.root_ancestor.id

        ::Search::ElasticGroupAssociationDeletionWorker.perform_async(group.id, old_root_ancestor_id,
          { include_descendants: true })
      end

      def process_wikis(group)
        return unless group.use_elasticsearch?

        group.self_and_descendants.find_each.with_index do |grp, idx|
          interval = idx % ElasticWikiIndexerWorker::MAX_JOBS_PER_HOUR
          ElasticWikiIndexerWorker.perform_in(interval, grp.id, grp.class.name, { force: true })
        end
      end

      override :remove_paid_features_for_projects
      def remove_paid_features_for_projects(old_root_ancestor_id)
        return if old_root_ancestor_id == group.root_ancestor.id

        group.all_projects.each do |project|
          ::EE::Projects::RemovePaidFeaturesService.new(project).execute(new_parent_group)
        end
      end
    end
  end
end
