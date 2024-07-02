# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class Workflow < ::ApplicationRecord
      self.table_name = :duo_workflows_workflows

      belongs_to :user
      belongs_to :project
      has_many :checkpoints, class_name: 'Ai::DuoWorkflows::Checkpoint'

      scope :for_user_with_id!, ->(user_id, id) { find_by!(user_id: user_id, id: id) }
    end
  end
end
