# frozen_string_literal: true

module Users
  class ProjectCallout < ApplicationRecord
    include Users::Calloutable

    self.table_name = 'user_project_callouts'

    belongs_to :project

    enum feature_name: {
      awaiting_members_banner: 1 # EE-only
    }

    validates :project, presence: true
    validates :feature_name,
              presence: true,
              uniqueness: { scope: [:user_id, :project_id] },
              inclusion: { in: ProjectCallout.feature_names.keys }
  end
end
