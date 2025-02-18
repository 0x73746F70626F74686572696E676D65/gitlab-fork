# frozen_string_literal: true

module Search
  module Zoekt
    class Replica < ApplicationRecord
      include NamespaceValidateable

      self.table_name = 'zoekt_replicas'

      enum state: {
        pending: 0,
        ready: 10
      }

      belongs_to :zoekt_enabled_namespace, inverse_of: :replicas, class_name: '::Search::Zoekt::EnabledNamespace'

      has_many :indices, foreign_key: :zoekt_replica_id, inverse_of: :replica

      validate :project_can_not_assigned_to_same_replica_unless_index_is_reallocating

      def self.for_enabled_namespace!(zoekt_enabled_namespace)
        zoekt_enabled_namespace.replicas.first_or_create!(namespace_id: zoekt_enabled_namespace.root_namespace_id)
      end

      private

      def project_can_not_assigned_to_same_replica_unless_index_is_reallocating
        return unless indices.joins(:zoekt_repositories).where.not(zoekt_repositories: { project_id: nil })
          .where.not(state: :reallocating).group('zoekt_repositories.project_id')
          .having('count(zoekt_indices.id) > 1').exists?

        errors.add(:base, 'A project can not be assigned to the same replica unless the index is being reallocated')
      end
    end
  end
end
