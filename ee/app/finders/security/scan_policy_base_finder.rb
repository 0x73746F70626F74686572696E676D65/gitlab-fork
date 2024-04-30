# frozen_string_literal: true

module Security
  class ScanPolicyBaseFinder
    def initialize(actor, object, policy_type, params)
      @actor = actor
      @object = object
      @policy_type = policy_type
      @params = params
    end

    def execute
      raise NotImplementedError
    end

    private

    attr_reader :actor, :object, :policy_type, :params

    def fetch_scan_policies
      return [] unless authorized_to_read_policy_configuration?

      fetch_policy_configurations
        .flat_map { |config| merge_project_relationship(config) }
    end

    def policy_configuration
      @policy_configuration ||= object.security_orchestration_policy_configuration
    end

    def authorized_to_read_policy_configuration?
      Ability.allowed?(actor, :read_security_orchestration_policies, object)
    end

    def fetch_policy_configurations
      case params[:relationship]
      when :inherited
        object.all_security_orchestration_policy_configurations(include_invalid: true)
      when :inherited_only
        object.all_inherited_security_orchestration_policy_configurations(include_invalid: true)
      when :descendant
        descendant_policy_configurations
      else
        default_policy_configurations
      end
    end

    def descendant_policy_configurations
      return default_policy_configurations if object.is_a?(Project)

      object.all_descendant_security_orchestration_policy_configurations
    end

    def default_policy_configurations
      return Array.wrap(policy_configuration) if params[:include_invalid]

      Array.wrap(policy_configuration).select { |config| config&.policy_configuration_valid? }
    end

    def merge_project_relationship(config)
      return [] unless config.respond_to? policy_type

      config.public_send(policy_type).map do |policy| # rubocop:disable GitlabSecurity/PublicSend
        policy.merge(
          config: config,
          project: config.project,
          namespace: config.namespace,
          inherited: config.source != object
        )
      end
    end
  end
end
