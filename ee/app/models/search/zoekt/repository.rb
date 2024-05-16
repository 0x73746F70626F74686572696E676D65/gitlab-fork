# frozen_string_literal: true

module Search
  module Zoekt
    class Repository < ApplicationRecord
      self.table_name = 'zoekt_repositories'

      belongs_to :zoekt_index, inverse_of: :zoekt_repositories, class_name: '::Search::Zoekt::Index'

      belongs_to :project, inverse_of: :zoekt_repository, class_name: 'Project'

      has_many :tasks,
        foreign_key: :zoekt_repository_id, inverse_of: :zoekt_repository, class_name: '::Search::Zoekt::Task'

      before_validation :set_project_identifier

      validates_presence_of :zoekt_index_id, :project_identifier, :state

      validate :project_id_matches_project_identifier

      validates :project_id, uniqueness: {
        scope: :zoekt_index_id, message: 'violates unique constraint between [:zoekt_index_id, :project_id]'
      }

      enum state: {
        pending: 0,
        initializing: 1,
        ready: 10
      }

      scope :non_ready, -> { where.not(state: :ready) }

      def self.create_tasks(project:, zoekt_index:, task_type:, perform_at:)
        find_or_initialize_by(project: project, zoekt_index: zoekt_index).tap do |record|
          record.save! if record.new_record?
          record.tasks.create!(
            zoekt_node_id: zoekt_index.zoekt_node_id,
            task_type: task_type,
            perform_at: perform_at
          )
        end
      end

      private

      def project_id_matches_project_identifier
        return unless project_id.present?
        return if project_id == project_identifier

        errors.add(:project_id, :invalid)
      end

      def set_project_identifier
        self.project_identifier ||= project_id
      end
    end
  end
end
