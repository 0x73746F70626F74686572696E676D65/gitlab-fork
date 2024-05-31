# frozen_string_literal: true

module Search
  module Zoekt
    class Index < ApplicationRecord
      self.table_name = 'zoekt_indices'
      include EachBatch

      SEARCHEABLE_STATES = %i[ready].freeze

      belongs_to :zoekt_enabled_namespace, inverse_of: :indices, class_name: '::Search::Zoekt::EnabledNamespace'
      belongs_to :node, foreign_key: :zoekt_node_id, inverse_of: :indices, class_name: '::Search::Zoekt::Node'

      has_many :zoekt_repositories, foreign_key: :zoekt_index_id, inverse_of: :zoekt_index,
        class_name: '::Search::Zoekt::Repository'

      validate :zoekt_enabled_root_namespace_matches_namespace_id

      after_commit :index, on: :create
      after_commit :delete_from_index, on: :destroy

      enum state: {
        pending: 0,
        in_progress: 1,
        initializing: 2,
        ready: 10
      }

      scope :for_node, ->(node) do
        where(node: node)
      end

      scope :for_root_namespace_id, ->(root_namespace_id) do
        where(namespace_id: root_namespace_id).where.not(zoekt_enabled_namespace_id: nil)
      end

      scope :searchable, -> do
        where(state: SEARCHEABLE_STATES)
          .joins(:zoekt_enabled_namespace)
          .where(zoekt_enabled_namespace: { search: true })
      end

      scope :for_root_namespace_id_with_search_enabled, ->(root_namespace_id) do
        for_root_namespace_id(root_namespace_id)
          .joins(:zoekt_enabled_namespace)
          .where(zoekt_enabled_namespace: { search: true })
      end

      scope :with_all_repositories_ready, -> do
        where_not_exists(Repository.non_ready.where(Repository.arel_table[:zoekt_index_id].eq(Index.arel_table[:id])))
          .where_exists(Repository.where(Repository.arel_table[:zoekt_index_id].eq(Index.arel_table[:id])))
      end

      scope :preload_zoekt_enabled_namespace_and_namespace, -> { includes(zoekt_enabled_namespace: :namespace) }
      scope :preload_node, -> { includes(:node) }

      private

      def zoekt_enabled_root_namespace_matches_namespace_id
        return unless zoekt_enabled_namespace.present? && namespace_id.present?
        return if zoekt_enabled_namespace.root_namespace_id == namespace_id

        errors.add(:namespace_id, :invalid)
      end

      def index
        ::Search::Zoekt::NamespaceIndexerWorker.perform_async(zoekt_enabled_namespace.root_namespace_id, :index)
      end

      def delete_from_index
        ::Search::Zoekt::NamespaceIndexerWorker.perform_async(namespace_id, :delete, zoekt_node_id)
      end
    end
  end
end
