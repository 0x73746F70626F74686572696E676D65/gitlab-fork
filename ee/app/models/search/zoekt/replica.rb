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

      def self.for_enabled_namespace!(zoekt_enabled_namespace)
        zoekt_enabled_namespace.replicas.first_or_create!(
          namespace_id: zoekt_enabled_namespace.root_namespace_id
        )
      end
    end
  end
end
