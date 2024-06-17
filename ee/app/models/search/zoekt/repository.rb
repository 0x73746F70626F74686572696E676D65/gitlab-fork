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

      validates :project_identifier, uniqueness: {
        scope: :zoekt_index_id, message: 'violates unique constraint between [:zoekt_index_id, :project_identifier]'
      }

      enum state: {
        pending: 0,
        initializing: 1,
        ready: 10
      }

      scope :non_ready, -> { where.not(state: :ready) }

      def self.create_tasks(project_id:, zoekt_index:, task_type:, perform_at:)
        project = Project.find_by_id(project_id)
        find_or_initialize_by(project_identifier: project_id, project: project, zoekt_index: zoekt_index).tap do |item|
          item.save! if item.new_record?
          item.tasks.create!(zoekt_node_id: zoekt_index.zoekt_node_id, task_type: task_type, perform_at: perform_at)
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
