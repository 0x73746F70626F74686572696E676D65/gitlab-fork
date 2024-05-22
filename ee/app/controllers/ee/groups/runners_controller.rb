# frozen_string_literal: true

module EE
  module Groups
    module RunnersController
      extend ActiveSupport::Concern

      class_methods do
        extend ::Gitlab::Utils::Override

        override :needs_authorize_read_group_runners
        def needs_authorize_read_group_runners
          super.concat([:dashboard])
        end
      end

      prepended do
        before_action :authorize_read_group_runners!, only: needs_authorize_read_group_runners

        before_action do
          next unless ::Gitlab::Ci::RunnerReleases.instance.enabled?

          push_licensed_feature(:runner_upgrade_management_for_namespace, group)
        end
      end

      def dashboard
        dashboard_available = ::Feature.enabled?(:runners_dashboard_for_groups, group) &&
          group.licensed_feature_available?(:runner_performance_insights_for_namespace)

        render_404 unless dashboard_available
      end
    end
  end
end
