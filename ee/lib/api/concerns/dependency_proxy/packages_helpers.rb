# frozen_string_literal: true

module API
  module Concerns
    module DependencyProxy
      module PackagesHelpers
        extend ActiveSupport::Concern

        TIMEOUTS = {
          open: 10,
          read: 10
        }.freeze

        RESPONSE_STATUSES = {
          error: :bad_gateway,
          timeout: :gateway_timeout
        }.freeze

        CALLBACKS_CLASS = Struct.new(:skip_upload, :before_respond_with)

        included do
          include ::API::Helpers::Authentication
          helpers ::API::Helpers::PackagesHelpers
          helpers ::API::Helpers::RelatedResourcesHelpers

          feature_category :package_registry
          urgency :low

          helpers do
            include ::Gitlab::Utils::StrongMemoize

            def dependency_proxy_setting
              setting = project.dependency_proxy_packages_setting
              external_registry_url_field = "#{package_format}_external_registry_url".to_sym
              return unless setting.enabled && setting[external_registry_url_field]

              return setting if can?(current_user, :read_package, setting)

              # guest users can have :read_project but not :read_package
              wrap_error_response { forbidden! } if can?(current_user, :read_project, project)
            end
            strong_memoize_attr :dependency_proxy_setting

            def destroy_package_file(package_file)
              return unless package_file

              ::Packages::MarkPackageFilesForDestructionService.new(
                ::Packages::PackageFile.id_in(package_file.id)
              ).execute
            end

            def respond_with(package_file:)
              result = ::DependencyProxy::Packages::VerifyPackageFileEtagService.new(
                remote_url: remote_package_file_url,
                package_file: package_file
              ).execute

              if result.success? || (result.error? && result.reason != :wrong_etag)
                track_file_pulled_event(from_cache: true)
                present_package_file!(package_file)
              elsif can?(current_user, :destroy_package, dependency_proxy_setting) &&
                  can?(current_user, :create_package, dependency_proxy_setting)
                destroy_package_file(package_file) if package_file

                send_and_upload_remote_url
              else
                send_remote_url
              end
            end

            def send_remote_url
              send_workhorse_headers(
                Gitlab::Workhorse.send_url(
                  remote_package_file_url,
                  headers: remote_url_headers,
                  allow_redirects: true,
                  timeouts: TIMEOUTS,
                  response_statuses: RESPONSE_STATUSES
                )
              )
            end

            def track_file_pulled_event(from_cache: false)
              return unless track_events?

              event_name = from_cache ? tracking_event_name(from: :cache) : tracking_event_name(from: :external)

              # we can't send deploy tokens to #track_event
              user = current_user if current_user.is_a?(User)

              ::Gitlab::InternalEvents.track_event(event_name, user: user, project: project)
            end

            def tracking_event_name(from:)
              "dependency_proxy_packages_#{package_format}_file_pulled_from_#{from}"
            end

            def send_and_upload_remote_url
              upload_config = {
                method: upload_method,
                url: upload_url,
                headers: upload_headers
              }

              send_workhorse_headers(
                Gitlab::Workhorse.send_dependency(
                  remote_url_headers,
                  remote_package_file_url,
                  upload_config: upload_config
                )
              )
            end

            def send_workhorse_headers(headers)
              track_file_pulled_event(from_cache: false)
              header(*headers)
              env['api.format'] = :binary
              content_type 'application/octet-stream'
              status :ok
              body ''
            end

            def handle(package_file)
              callbacks = CALLBACKS_CLASS.new

              yield callbacks if block_given?

              if package_file
                handle_existing_file(package_file: package_file, callbacks: callbacks)
              else
                handle_new_file(callbacks: callbacks)
              end
            end

            def handle_existing_file(package_file:, callbacks:)
              result = callbacks.before_respond_with&.call
              return result unless result.blank?

              respond_with(package_file: package_file)
            end

            def handle_new_file(callbacks:)
              if can?(current_user, :create_package, dependency_proxy_setting) && !callbacks.skip_upload&.call
                send_and_upload_remote_url
              else
                send_remote_url
              end
            end

            def upload_headers
              {}
            end

            def upload_method
              'POST'
            end

            def remote_url_headers
              {}
            end

            def package_format
              options[:for].name.demodulize.underscore
            end

            def wrap_error_response
              yield
            end

            def track_events?
              true
            end
          end

          after_validation do
            require_packages_enabled!
            require_dependency_proxy_enabled!

            wrap_error_response { not_found! } unless dependency_proxy_setting

            unless project.licensed_feature_available?(:dependency_proxy_for_packages)
              wrap_error_response { forbidden! }
            end
          end
        end
      end
    end
  end
end
