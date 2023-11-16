# frozen_string_literal: true

module QA
  module EE
    module Strategy
      extend self

      DEB_PURL_TYPE = 11

      def perform_before_hooks
        QA::CE::Strategy.perform_before_hooks

        if QA::Runtime::Env.ee_license.present?
          QA::Runtime::Logger.info("Performing initial license fabrication!")
          QA::Page::Main::Menu.perform(&:sign_out_if_signed_in)

          EE::Resource::License.fabricate! do |resource|
            resource.license = QA::Runtime::Env.ee_license
          end
        end

        unless QA::Runtime::Env.running_on_dot_com?
          QA::Runtime::Logger.info("Disabling sync with External package metadata database")
          # we can't pass [] here, otherwise it causes a validation error, because the value we pass
          # must be a valid purl_type. Instead, we pass the `deb` purl_type which is only used for
          # container scanning advisories, which are not yet supported/ingested, so this is effectively
          # the same thing as disabling the sync.
          QA::Runtime::ApplicationSettings.set_application_settings(package_metadata_purl_types: [DEB_PURL_TYPE])
        end

        QA::Page::Main::Menu.perform(&:sign_out_if_signed_in)
      end
    end
  end
end
