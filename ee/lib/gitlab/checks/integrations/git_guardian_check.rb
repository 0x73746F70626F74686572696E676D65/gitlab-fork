# frozen_string_literal: true

module Gitlab
  module Checks
    module Integrations
      class GitGuardianCheck < ::Gitlab::Checks::BaseBulkChecker
        BLOB_BYTES_LIMIT = 1.megabyte

        LOG_MESSAGE = 'Starting GitGuardian scan...'
        SPECIAL_COMMIT_FLAG = /\[skip secret detection\]/i

        REMEDIATION_MESSAGE = <<~MESSAGE
          How to remediate:

          The violation was detected before the commit was pushed:

          1. Fix the violation in the detected files.
          2. Commit and try pushing again.

          [To apply with caution] If you want to bypass the secrets check:

          1. Add [skip secret detection] flag to the commit message.
          2. Commit and try pushing again.
        MESSAGE

        def initialize(integration_check)
          @changes_access = integration_check.changes_access
        end

        def validate!
          return unless integration_activated?
          return if skip_secret_detection?

          logger.log_timed(LOG_MESSAGE) do
            blobs = changed_blobs(timeout: logger.time_left)
            blobs.reject! { |blob| blob.size > BLOB_BYTES_LIMIT || blob.binary }

            format_git_guardian_response do
              project.git_guardian_integration.execute(blobs)
            end
          end
        end

        private

        def integration_activated?
          integration = project.git_guardian_integration

          integration.present? && integration.activated?
        end

        def changed_blobs(timeout:)
          ::Gitlab::Checks::ChangedBlobs.new(
            project, revisions, bytes_limit: BLOB_BYTES_LIMIT + 1, with_paths: true
          ).execute(timeout: timeout)
        end

        def skip_secret_detection?
          changes_access.commits.any? { |commit| commit.safe_message =~ SPECIAL_COMMIT_FLAG }
        end

        def revisions
          @revisions ||= changes_access
                           .changes
                           .pluck(:newrev) # rubocop:disable CodeReuse/ActiveRecord -- Array#pluck
                           .reject { |revision| ::Gitlab::Git.blank_ref?(revision) }
                           .compact
        end

        def format_git_guardian_response
          response = yield

          return unless response.present?

          message = response.join("\n") << REMEDIATION_MESSAGE

          raise ::Gitlab::GitAccess::ForbiddenError, message
        rescue Gitlab::GitGuardian::Client::RequestError => e
          raise ::Gitlab::GitAccess::ForbiddenError, "GitGuardian API error: #{e.message}"
        end
      end
    end
  end
end
