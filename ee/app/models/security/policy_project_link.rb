# frozen_string_literal: true

module Security
  class PolicyProjectLink < ApplicationRecord
    self.table_name = 'security_policy_project_links'

    belongs_to :project
    belongs_to :security_policy, class_name: 'Security::Policy', inverse_of: :security_policy_project_links

    validates :security_policy, uniqueness: { scope: :project_id }
  end
end
