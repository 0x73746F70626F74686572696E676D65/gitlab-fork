# frozen_string_literal: true

module EE
  module Admin
    module ApplicationSettingsController
      extend ::Gitlab::Utils::Override
      extend ActiveSupport::Concern

      UNINDEXED_PROJECT_DISPLAY_LIMIT = 50

      prepended do
        include MicrosoftApplicationActions

        before_action :elasticsearch_reindexing_task, only: [:advanced_search]
        before_action :elasticsearch_index_settings, only: [:advanced_search]
        before_action :elasticsearch_warn_if_not_using_aliases, only: [:advanced_search]
        before_action :elasticsearch_warn_if_obsolete_migrations, only: [:advanced_search]
        before_action :elasticsearch_pending_obsolete_migrations, only: [:advanced_search]
        before_action :search_error_if_version_incompatible, only: [:advanced_search]
        before_action :search_outdated_code_analyzer_detected, only: [:advanced_search]
        before_action :push_password_complexity_feature, only: [:general]
        before_action :new_license, only: [:general]
        before_action :scim_token, only: [:general]
        before_action :find_or_initialize_microsoft_application, only: [:general]
        before_action :verify_namespace_plan_check_enabled, only: [:namespace_storage]
        before_action :indexing_status, only: [:advanced_search]

        before_action :push_disable_private_profiles_feature, only: [:general]

        feature_category :plan_provisioning, [:seat_link_payload]
        feature_category :source_code_management, [:templates]
        feature_category :global_search, [:advanced_search]
        feature_category :software_composition_analysis, [:security_and_compliance]
        feature_category :consumables_cost_management, [:namespace_storage]
        feature_category :product_analytics_data_management, [:analytics]
        urgency :low, [:advanced_search, :seat_link_payload]

        def elasticsearch_reindexing_task
          @last_elasticsearch_reindexing_task = Elastic::ReindexingTask.last
          @elasticsearch_reindexing_task = Elastic::ReindexingTask.new
        end

        def elasticsearch_index_settings
          @elasticsearch_index_settings = Elastic::IndexSetting.order_by_name
        end

        def elasticsearch_warn_if_not_using_aliases
          @elasticsearch_warn_if_not_using_aliases = ::Gitlab::Elastic::Helper.default.alias_missing? &&
            ::Gitlab::Elastic::Helper.default.index_exists?
        rescue StandardError => e
          log_exception(e)
        end

        def elasticsearch_warn_if_obsolete_migrations
          @elasticsearch_warn_if_obsolete_migrations = ::Gitlab::Elastic::Helper.default.ping? &&
            elasticsearch_pending_obsolete_migrations.any?
        end

        def elasticsearch_pending_obsolete_migrations
          @elasticsearch_pending_obsolete_migrations =
            Elastic::DataMigrationService.pending_migrations.select(&:obsolete?)
        end

        def search_error_if_version_incompatible
          @search_error_if_version_incompatible = !::Gitlab::Elastic::Helper.default.supported_version?
        end

        def search_outdated_code_analyzer_detected
          @search_outdated_code_analyzer_detected = begin
            current_index_version = ::Gitlab::Elastic::Helper.default.get_meta&.dig('created_by')
            version_info = ::Gitlab::VersionInfo.parse(current_index_version)

            if version_info.valid?
              version_info < ::Gitlab::VersionInfo.new(15, 5)
            else
              true # a very outdated version of GitLab
            end
          end
        rescue StandardError => e
          log_exception(e)
        end

        def scim_token
          scim_token = ScimOauthAccessToken.find_for_instance

          @scim_token_url = scim_token.as_entity_json[:scim_api_url] if scim_token
        end

        def indexing_status
          @initial_queue_size = ::Elastic::ProcessInitialBookkeepingService.queue_size
          @incremental_queue_size = ::Elastic::ProcessBookkeepingService.queue_size

          # This code cannot be run on GitLab.com due to performance issues
          return if ::Gitlab::Saas.feature_available?(:search_indexing_status)

          @projects_not_indexed_count = ::Search::ElasticProjectsNotIndexedFinder.execute.count
          @projects_not_indexed = ::Search::ElasticProjectsNotIndexedFinder
            .execute.limit(UNINDEXED_PROJECT_DISPLAY_LIMIT)
        end
      end

      EE_VALID_SETTING_PANELS = %w[advanced_search templates security_and_compliance namespace_storage].freeze

      EE_VALID_SETTING_PANELS.each do |action|
        define_method(action) { perform_update if submitted? }
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      def visible_application_setting_attributes
        attrs = super

        if License.feature_available?(:repository_mirrors)
          attrs += EE::ApplicationSettingsHelper.repository_mirror_attributes
        end

        # License feature => attribute name
        {
          custom_project_templates: :custom_project_templates_group_id,
          email_additional_text: :email_additional_text,
          custom_file_templates: :file_template_project_id,
          default_project_deletion_protection: :default_project_deletion_protection,
          adjourned_deletion_for_projects_and_groups: :deletion_adjourned_period,
          disable_name_update_for_users: :updating_name_disabled_for_users,
          package_forwarding: [:npm_package_requests_forwarding,
                               :lock_npm_package_requests_forwarding,
                               :pypi_package_requests_forwarding,
                               :lock_pypi_package_requests_forwarding,
                               :maven_package_requests_forwarding,
                               :lock_maven_package_requests_forwarding],
          default_branch_protection_restriction_in_groups: :group_owners_can_manage_default_branch_protection,
          group_ip_restriction: :globally_allowed_ips,
          service_accounts: :service_access_tokens_expiration_enforced
        }.each do |license_feature, attribute_names|
          if License.feature_available?(license_feature)
            attrs += Array.wrap(attribute_names)
          end
        end

        if License.feature_available?(:git_two_factor_enforcement) && ::Feature.enabled?(:two_factor_for_cli)
          attrs << :git_two_factor_session_expiry
        end

        # Remove the inline rubocop disablement of Metrics/PerceivedComplexity when we can move
        # pre_receive_secret_detection_enabled to the simple License feature => attribute name
        # hash above.
        if (::Gitlab::CurrentSettings.gitlab_dedicated_instance? ||
            ::Feature.enabled?(:pre_receive_secret_detection_beta_release)) &&
            License.feature_available?(:pre_receive_secret_detection)

          attrs << :pre_receive_secret_detection_enabled
        end

        if License.feature_available?(:admin_merge_request_approvers_rules)
          attrs += EE::ApplicationSettingsHelper.merge_request_appovers_rules_attributes
        end

        if ::License.feature_available?(:password_complexity)
          attrs += EE::ApplicationSettingsHelper.password_complexity_attributes
        end

        if License.feature_available?(:elastic_search)
          attrs += [
            elasticsearch_shards: {},
            elasticsearch_replicas: {}
          ]
        end

        if RegistrationFeatures::MaintenanceMode.feature_available?
          attrs << :maintenance_mode
          attrs << :maintenance_mode_message
        end

        if License.feature_available?(:disable_private_profiles) && ::Feature.enabled?(:disallow_private_profiles)
          attrs << :make_profile_private
        end

        attrs << :new_user_signups_cap
        attrs << :namespace_storage_forks_cost_factor

        if License.feature_available?(:code_owner_approval_required)
          defaults = attrs.find do |item|
            item.is_a?(Hash) && item.key?(:default_branch_protection_defaults)
          end

          defaults[:default_branch_protection_defaults] << :code_owner_approval_required
        end

        if CloudConnector::AvailableServices.find_by_name(:code_suggestions)&.purchased?
          attrs << :disabled_direct_code_suggestions
        end

        attrs
      end
      # rubocop:enable Metrics/PerceivedComplexity
      # rubocop:enable Metrics/CyclomaticComplexity

      def seat_link_payload
        data = ::Gitlab::SeatLinkData.new

        respond_to do |format|
          format.html do
            seat_link_json = ::Gitlab::Json.pretty_generate(data)

            render html: ::Gitlab::Highlight.highlight('payload.json', seat_link_json, language: 'json')
          end
          format.json { render json: data.to_json }
        end
      end

      def analytics
        not_found unless ::License.feature_available?(:product_analytics)
      end

      def push_disable_private_profiles_feature
        push_licensed_feature(:disable_private_profiles) if ::Feature.enabled?(:disallow_private_profiles)
      end

      private

      override :valid_setting_panels
      def valid_setting_panels
        super + EE_VALID_SETTING_PANELS
      end

      def push_password_complexity_feature
        push_licensed_feature(:password_complexity)
      end

      def new_license
        @new_license ||= License.new(data: params[:trial_key]) # rubocop:disable Gitlab/ModuleWithInstanceVariables
      end

      def sync_cloud_connector_access_data
        ::CloudConnector::SyncServiceTokenWorker.perform_async
      end

      def microsoft_application_namespace
        nil
      end

      def microsoft_application_redirect_path
        general_admin_application_settings_path
      end

      def microsoft_group_sync_enabled?
        ::Gitlab::Auth::Saml::Config.microsoft_group_sync_enabled?
      end
    end
  end
end
