# frozen_string_literal: true

module RemoteDevelopment
  class Workspace < ApplicationRecord
    include IgnorableColumns
    include Sortable
    include RemoteDevelopment::Workspaces::States
    include ::Gitlab::Utils::StrongMemoize

    ignore_column :url_domain, remove_with: '16.9', remove_after: '2019-01-19'

    belongs_to :user, inverse_of: :workspaces
    belongs_to :project, inverse_of: :workspaces
    belongs_to :agent, class_name: 'Clusters::Agent', foreign_key: 'cluster_agent_id', inverse_of: :workspaces
    belongs_to :personal_access_token, inverse_of: :workspace

    # noinspection RailsParamDefResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
    has_one :remote_development_agent_config, through: :agent, source: :remote_development_agent_config
    has_many :workspace_variables, class_name: 'RemoteDevelopment::WorkspaceVariable', inverse_of: :workspace

    validates :user, presence: true
    validates :agent, presence: true
    validates :editor, presence: true
    validates :personal_access_token, presence: true

    # Ensure that the associated agent has an existing RemoteDevelopmentAgentConfig before we allow it
    # to be used to create a new workspace
    validate :validate_agent_config_present_and_enabled, on: :create

    validate :validate_dns_zone_matches_remote_development_agent_config_dns_zone

    # See https://gitlab.com/gitlab-org/remote-development/gitlab-remote-development-docs/blob/main/doc/architecture.md?plain=0#workspace-states
    # for state validation rules
    validates :desired_state, inclusion: { in: VALID_DESIRED_STATES }
    validates :actual_state, inclusion: { in: VALID_ACTUAL_STATES }
    validates :editor, inclusion: { in: ['webide'], message: "'webide' is currently the only supported editor" }
    validates :max_hours_before_termination, numericality: {
      less_than_or_equal_to: :max_hours_before_termination_limit
    }

    validate :enforce_permanent_termination
    validate :enforce_quotas, on: :create

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

    def workspaces_count_for_current_user_and_agent
      Workspace
        .desired_state_not_terminated
        .by_user_ids(user_id)
        .by_agent_ids(cluster_agent_id)
        .count
    end

    strong_memoize_attr :workspaces_count_for_current_user_and_agent

    def workspaces_count_for_current_agent
      Workspace
        .desired_state_not_terminated
        .by_agent_ids(cluster_agent_id)
        .count
    end

    strong_memoize_attr :workspaces_count_for_current_agent

    def exceeds_workspaces_per_user_quota?
      return unless remote_development_agent_config

      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      quota = remote_development_agent_config.workspaces_per_user_quota
      return true if quota == 0
      return false if quota == -1

      workspaces_count_for_current_user_and_agent >= quota
    end

    def exceeds_workspaces_quota?
      return unless remote_development_agent_config

      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      quota = remote_development_agent_config.workspaces_quota
      return true if quota == 0
      return false if quota == -1

      workspaces_count_for_current_agent >= quota
    end

    def url
      URI::HTTPS.build(host: "#{url_prefix}.#{dns_zone}", query: url_query_string).to_s
    end

    def devfile_web_url
      project.http_url_to_repo.gsub(/\.git$/, "/-/blob/#{devfile_ref}/#{devfile_path}")
    end

    private

    def max_hours_before_termination_limit
      RemoteDevelopment::Settings.get_single_setting(:max_hours_before_termination_limit)
    end

    def validate_agent_config_present_and_enabled
      unless agent&.remote_development_agent_config
        errors.add(:agent, _('for Workspace must have an associated RemoteDevelopmentAgentConfig'))
        return false
      end

      return true if agent.remote_development_agent_config.enabled

      errors.add(:agent, _("must have the 'enabled' flag set to true"))
      false
    end

    def validate_dns_zone_matches_remote_development_agent_config_dns_zone
      return if desired_state == TERMINATED

      unless agent&.remote_development_agent_config&.dns_zone == dns_zone
        errors.add(
          :dns_zone,
          _('for Workspace must match the dns_zone of the associated RemoteDevelopmentAgentConfig'))
        return false
      end

      true
    end

    def enforce_permanent_termination
      return unless persisted? && desired_state_changed? && desired_state_was == Workspaces::States::TERMINATED

      errors.add(:desired_state, "is 'Terminated', and cannot be updated. Create a new workspace instead.")
    end

    # rubocop:disable Layout/LineLength  -- Long messages for UI
    def enforce_quotas
      agent_config = remote_development_agent_config
      if exceeds_workspaces_per_user_quota?
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        errors.add :base,
          format(
            s_('RemoteDevelopment|You cannot create a workspace because you already have "%{count}" existing workspaces for the given agent with a per user quota of "%{quota}" workspaces'),
            count: workspaces_count_for_current_user_and_agent,
            quota: agent_config.workspaces_per_user_quota
          )
      elsif exceeds_workspaces_quota?
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        errors.add :base,
          format(
            s_('RemoteDevelopment|You cannot create a workspace because there are already "%{count}" existing workspaces for the given agent with a total quota of "%{quota}" workspaces'),
            count: workspaces_count_for_current_agent,
            quota: agent_config.workspaces_quota
          )
      end
    end

    # rubocop:enable Layout/LineLength  -- Long messages for UI

    def touch_desired_state_updated_at
      self.desired_state_updated_at = Time.current.utc
    end
  end
end
