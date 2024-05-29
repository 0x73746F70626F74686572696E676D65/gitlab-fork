# frozen_string_literal: true

module Namespaces
  class CascadeDuoFeaturesEnabledWorker
    include ApplicationWorker
    extend ActiveSupport::Concern

    feature_category :ai_abstraction_layer

    idempotent!
    deduplicate :until_executed, if_deduplicated: :reschedule_once
    urgency :low
    data_consistency :delayed
    loggable_arguments 0
    worker_resource_boundary :memory

    def perform(*args)
      group_id = args[0]
      group = Group.find(group_id)
      duo_features_enabled = group.namespace_settings.duo_features_enabled

      projects = group.all_projects
      subgroups = group.self_and_descendants

      projects.each_batch do |batch|
        project_ids_to_update = batch.pluck_primary_key
        ProjectSetting.for_projects(project_ids_to_update)
                      .duo_features_set(!duo_features_enabled)
                      .update_all(duo_features_enabled: duo_features_enabled)
      end

      subgroups.each_batch do |batch|
        namespace_ids = batch.pluck_primary_key
        NamespaceSetting.for_namespaces(namespace_ids)
                        .duo_features_set(!duo_features_enabled)
                        .update_all(duo_features_enabled: duo_features_enabled)
      end
    end
  end
end
