# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class Workflow < ::ApplicationRecord
      self.table_name = :duo_workflows_workflows

      belongs_to :user
      belongs_to :project
      has_many :checkpoints, class_name: 'Ai::DuoWorkflows::Checkpoint'

      validates :status, presence: true

      scope :for_user_with_id!, ->(user_id, id) { find_by!(user_id: user_id, id: id) }

      state_machine :status, initial: :created do
        event :start do
          transition created: :running
        end

        event :pause do
          transition running: :paused
        end

        event :resume do
          transition paused: :running
        end

        event :finish do
          transition running: :finished
        end

        event :drop do
          transition [:created, :running, :paused] => :failed
        end

        state :created, value: 0
        state :running, value: 1
        state :paused, value: 2
        state :finished, value: 3
        state :failed, value: 4
      end
    end
  end
end
