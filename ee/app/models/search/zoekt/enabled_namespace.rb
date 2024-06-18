# frozen_string_literal: true

module Search
  module Zoekt
    class EnabledNamespace < ApplicationRecord
      include EachBatch

      self.table_name = 'zoekt_enabled_namespaces'

      belongs_to :namespace, class_name: 'Namespace',
        foreign_key: :root_namespace_id, inverse_of: :zoekt_enabled_namespace

      has_many :indices, class_name: '::Search::Zoekt::Index',
        foreign_key: :zoekt_enabled_namespace_id, inverse_of: :zoekt_enabled_namespace,
        dependent: :destroy # TODO: Remove this after the cleanup task is implemented
      has_many :nodes, through: :indices

      has_many :replicas, dependent: :destroy,
        foreign_key: :zoekt_enabled_namespace_id, inverse_of: :zoekt_enabled_namespace

      validate :only_root_namespaces_can_be_indexed

      scope :for_root_namespace_id, ->(root_namespace_id) { where(root_namespace_id: root_namespace_id) }
      scope :preload_storage_statistics, -> { includes(namespace: :root_storage_statistics) }
      scope :recent, -> { order(id: :desc) }
      scope :search_enabled, -> { where(search: true) }
      scope :with_limit, ->(maximum) { limit(maximum) }
      scope :with_missing_indices, -> { left_joins(:indices).where(zoekt_indices: { zoekt_enabled_namespace_id: nil }) }

      def self.destroy_namespaces_with_expired_subscriptions!
        before_date = Date.today - Search::Zoekt::EXPIRED_SUBSCRIPTION_GRACE_PERIOD

        each_batch(column: :root_namespace_id) do |batch|
          namespace_ids = batch.pluck(:root_namespace_id) # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- it is limited by each_batch already

          namespace_with_subscription_ids = GitlabSubscription.where(namespace_id: namespace_ids)
            .with_a_paid_hosted_plan
            .not_expired(before_date: before_date)
            .pluck(:namespace_id) # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- it is limited by each_batch already

          namespace_to_remove_ids = namespace_ids - namespace_with_subscription_ids
          next if namespace_to_remove_ids.empty?

          where(root_namespace_id: namespace_to_remove_ids).find_each(&:destroy)
        end
      end

      private

      def only_root_namespaces_can_be_indexed
        return if namespace&.root?

        errors.add(:root_namespace_id, 'Only root namespaces can be indexed')
      end
    end
  end
end
