# frozen_string_literal: true

module Audit # rubocop:disable Gitlab/BoundedContexts -- govern::compliance will need to refactor all instances of Audit
  class ProjectAnalyticsChangesAuditor < BaseChangesAuditor
    ATTRIBUTE_NAMES = [
      :product_analytics_configurator_connection_string,
      :product_analytics_data_collector_host,
      :cube_api_base_url,
      :cube_api_key
    ].freeze

    def initialize(current_user, project_setting, project)
      @project = project

      super(current_user, project_setting)
    end

    def execute
      ATTRIBUTE_NAMES.each do |attr|
        next unless model.previous_changes.key?(attr.to_s)

        audit_context = {
          name: 'product_analytics_settings_update',
          author: @current_user,
          scope: @project,
          target: @project,
          message: "Changed #{attr}",
          additional_details: details(attr)
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end

    def details(column)
      return { change: column } if
        [:product_analytics_configurator_connection_string, :cube_api_key].include?(column)

      {
        change: column,
        from: @model.previous_changes[column].first,
        to: @model.previous_changes[column].last
      }
    end
  end
end
