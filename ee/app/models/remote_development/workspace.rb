# frozen_string_literal: true

module RemoteDevelopment
  class Workspace < ApplicationRecord
    include IgnorableColumns
    include Sortable
    # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
    include RemoteDevelopment::Workspaces::States

    MAX_HOURS_BEFORE_TERMINATION_LIMIT = 120

    ignore_column :url_domain, remove_with: '16.9', remove_after: '2019-01-19'

    belongs_to :user, inverse_of: :workspaces
    belongs_to :project, inverse_of: :workspaces
    belongs_to :agent, class_name: 'Clusters::Agent', foreign_key: 'cluster_agent_id', inverse_of: :workspaces
    belongs_to :personal_access_token, inverse_of: :workspace

    # noinspection RailsParamDefResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
    has_one :remote_development_agent_config, through: :agent, source: :remote_development_agent_config
    has_many :workspace_variables, class_name: 'RemoteDevelopment::WorkspaceVariable', inverse_of: :workspace

    delegate :dns_zone, to: :remote_development_agent_config, prefix: false, allow_nil: false

    validates :user, presence: true
    validates :agent, presence: true
    validates :editor, presence: true
    validates :personal_access_token, presence: true

    # Ensure that the associated agent has an existing RemoteDevelopmentAgentConfig before we allow it
    # to be used to create a new workspace
    validate :validate_agent_config_presence

    # See https://gitlab.com/gitlab-org/remote-development/gitlab-remote-development-docs/blob/main/doc/architecture.md?plain=0#workspace-states
    # for state validation rules
    validates :desired_state, inclusion: { in: VALID_DESIRED_STATES }
    validates :actual_state, inclusion: { in: VALID_ACTUAL_STATES }
    validates :editor, inclusion: { in: ['webide'], message: "'webide' is currently the only supported editor" }
    validates :max_hours_before_termination, numericality: { less_than_or_equal_to: MAX_HOURS_BEFORE_TERMINATION_LIMIT }

    validate :enforce_permanent_termination

    scope :with_desired_state_updated_more_recently_than_last_response_to_agent, -> do
      where('desired_state_updated_at >= responded_to_agent_at').or(where(responded_to_agent_at: nil))
    end

    scope :forced_to_include_all_resources, -> { where(force_include_all_resources: true) }
    scope :by_user_ids, ->(ids) { where(user_id: ids) }
    scope :by_project_ids, ->(ids) { where(project_id: ids) }
    scope :by_agent_ids, ->(ids) { where(cluster_agent_id: ids) }
    scope :by_actual_states, ->(actual_states) { where(actual_state: actual_states) }
    scope :desired_state_not_terminated, -> do
      where.not(
        desired_state: RemoteDevelopment::Workspaces::States::TERMINATED
      )
    end
    scope :actual_state_not_terminated, -> do
      where.not(
        actual_state: RemoteDevelopment::Workspaces::States::TERMINATED
      )
    end

    # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-32287
    before_save :touch_desired_state_updated_at, if: ->(workspace) do
      workspace.new_record? || workspace.desired_state_changed?
    end

    def desired_state_updated_more_recently_than_last_response_to_agent?
      return true if responded_to_agent_at.nil?

      desired_state_updated_at >= responded_to_agent_at
    end

    private

    def validate_agent_config_presence
      unless agent&.remote_development_agent_config
        errors.add(:agent, _('for Workspace must have an associated RemoteDevelopmentAgentConfig'))
        return false
      end

      return true if agent.remote_development_agent_config.enabled

      errors.add(:agent, _("must have the 'enabled' flag set to true"))
      false
    end

    def enforce_permanent_termination
      return unless persisted? && desired_state_changed? && desired_state_was == Workspaces::States::TERMINATED

      errors.add(:desired_state, "is 'Terminated', and cannot be updated. Create a new workspace instead.")
    end

    def touch_desired_state_updated_at
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      self.desired_state_updated_at = Time.current.utc
    end
  end
end
