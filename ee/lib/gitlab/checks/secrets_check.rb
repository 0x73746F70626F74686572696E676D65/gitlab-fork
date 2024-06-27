# frozen_string_literal: true

module Gitlab
  module Checks
    class SecretsCheck < ::Gitlab::Checks::BaseBulkChecker
      include Gitlab::InternalEventsTracking

      ERROR_MESSAGES = {
        failed_to_scan_regex_error: "\n    - Failed to scan blob(id: %{blob_id}) due to regex error.",
        blob_timed_out_error: "\n    - Scanning blob(id: %{blob_id}) timed out.",
        scan_timeout_error: 'Secret detection scan timed out.',
        scan_initialization_error: 'Secret detection scan failed to initialize.',
        invalid_input_error: 'Secret detection scan failed due to invalid input.',
        invalid_scan_status_code_error: 'Invalid secret detection scan status, check passed.',
        too_many_tree_entries_error: 'Too many tree entries exist for commit(sha: %{sha}).'
      }.freeze

      LOG_MESSAGES = {
        secrets_check: 'Detecting secrets...',
        secrets_not_found: 'Secret detection scan completed with no findings.',
        skip_secret_detection: "\n\nTo skip secret push protection, add the following Git push option" \
                               "to your push command: `-o secret_detection.skip_all`",
        found_secrets: "\nPUSH BLOCKED: Secrets detected in code changes",
        found_secrets_post_message: "\n\nTo push your changes you must remove the identified secrets.",
        found_secrets_docs_link: "\nFor guidance, see %{path}",
        found_secrets_with_errors: 'Secret detection scan completed with one or more findings ' \
                                   'but some errors occured during the scan.',
        finding_message_occurrence_header: "\n\nSecret push protection " \
                                           "found the following secrets in commit: %{sha}",
        finding_message_occurrence_path: "\n-- %{path}:",
        finding_message_occurrence_line: "%{line_number} | %{description}",
        finding_message: "\n\nSecret leaked in blob: %{blob_id}" \
                         "\n  -- line:%{line_number} | %{description}",
        found_secrets_footer: "\n--------------------------------------------------\n\n"
      }.freeze

      BLOB_BYTES_LIMIT = 1.megabyte # Limit is 1MiB to start with.
      SPECIAL_COMMIT_FLAG = /\[skip secret detection\]/i
      DOCUMENTATION_PATH = 'user/application_security/secret_detection/secret_push_protection/index.html'
      DOCUMENTATION_PATH_ANCHOR = 'resolve-a-blocked-push'

      def validate!
        # Return early and do not perform the check:
        #   1. unless license is ultimate
        #   2. unless application setting is enabled (regardless of whether it's a gitlab dedicated instance or not)
        #   3. unless we are on GitLab.com or a Dedicated instance
        #   4. unless feature flag is enabled for this project (when instance type is GitLab.com)
        #   5. if it is a delete branch/tag operation, as it would require scanning the entire revision history
        #   6. if options are passed for us to skip the check

        return unless project.licensed_feature_available?(:pre_receive_secret_detection)

        return unless run_pre_receive_secret_detection?

        return if includes_full_revision_history?

        # Skip if any commit has the special bypass flag `[skip secret detection]`
        if skip_secret_detection_commit_message?
          log_audit_event(_("commit message")) # Keeping this a string and not constant so I18N picks it up
          track_spp_skipped("commit message")
          return
        end

        if skip_secret_detection_push_option?
          log_audit_event(_("push option")) # Keeping this a string and not constant so I18N picks it up
          track_spp_skipped("push option")
          return
        end

        logger.log_timed(LOG_MESSAGES[:secrets_check]) do
          blobs = ::Gitlab::Checks::ChangedBlobs.new(
            project, revisions, bytes_limit: BLOB_BYTES_LIMIT + 1
          ).execute(timeout: logger.time_left)

          # Filter out larger than BLOB_BYTES_LIMIT blobs and binary blobs.
          blobs.reject! { |blob| blob.size > BLOB_BYTES_LIMIT || blob.binary }

          # Pass blobs to gem for scanning.
          response = ::Gitlab::SecretDetection::Scan
            .new(logger: secret_detection_logger)
            .secrets_scan(blobs, timeout: logger.time_left)

          # Handle the response depending on the status returned.
          format_response(response)

        # TODO: Perhaps have a separate message for each and better logging?
        rescue ::Gitlab::SecretDetection::Scan::RulesetParseError,
          ::Gitlab::SecretDetection::Scan::RulesetCompilationError => _
          secret_detection_logger.error(message: ERROR_MESSAGES[:scan_initialization_error])
        end
      end

      private

      # As the pre-receive feature moves to Beta,
      # we are restricting to Dedicated and select
      # GitLab.com projects. For progress, follow
      # https://gitlab.com/groups/gitlab-org/-/epics/12729
      def run_pre_receive_secret_detection?
        Gitlab::CurrentSettings.current_application_settings.pre_receive_secret_detection_enabled &&
          (enabled_for_gitlabcom_project? || enabled_for_dedicated_project?)
      end

      def enabled_for_gitlabcom_project?
        ::Gitlab::Saas.feature_available?(:beta_rollout_pre_receive_secret_detection) &&
          ::Feature.enabled?(:pre_receive_secret_detection_push_check, project) &&
          project.security_setting&.pre_receive_secret_detection_enabled
      end

      def enabled_for_dedicated_project?
        ::Gitlab::CurrentSettings.gitlab_dedicated_instance &&
          project.security_setting&.pre_receive_secret_detection_enabled
      end

      def includes_full_revision_history?
        Gitlab::Git.blank_ref?(changes_access.changes.first[:newrev])
      end

      def skip_secret_detection_commit_message?
        changes_access.commits.any? { |commit| commit.safe_message =~ SPECIAL_COMMIT_FLAG }
      end

      def skip_secret_detection_push_option?
        changes_access.push_options&.get(:secret_detection, :skip_all)
      end

      def secret_detection_logger
        @secret_detection_logger ||= ::Gitlab::SecretDetectionLogger.build
      end

      def log_audit_event(skip_method)
        message = "#{_('Secret push protection skipped via')} #{skip_method}"

        audit_context = {
          name: "skip_secret_push_protection",
          author: changes_access.user_access.user,
          target: project,
          scope: project,
          message: message
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def track_spp_skipped(skip_method)
        track_internal_event(
          "skip_secret_push_protection",
          user: changes_access.user_access.user,
          project: project,
          namespace: project.namespace,
          additional_properties: {
            label: skip_method
          }
        )
      end

      def format_response(response)
        # Try to retrieve file path and commit sha for the blobs found.
        if [
          ::Gitlab::SecretDetection::Status::FOUND,
          ::Gitlab::SecretDetection::Status::FOUND_WITH_ERRORS
        ].include?(response.status)
          # TODO: filter out revisions not related to found secrets
          results = transform_findings(response)
        end

        case response.status
        when ::Gitlab::SecretDetection::Status::NOT_FOUND
          # No secrets found, we log and skip the check.
          secret_detection_logger.info(message: LOG_MESSAGES[:secrets_not_found])
        when ::Gitlab::SecretDetection::Status::FOUND
          # One or more secrets found, generate message with findings and fail check.
          message = build_secrets_found_message(results)

          secret_detection_logger.info(message: LOG_MESSAGES[:found_secrets])

          raise ::Gitlab::GitAccess::ForbiddenError, message
        when ::Gitlab::SecretDetection::Status::FOUND_WITH_ERRORS
          # One or more secrets found, but with scan errors, so we
          # generate a message with findings and errors, and fail the check.
          message = build_secrets_found_message(results, with_errors: true)

          secret_detection_logger.info(message: LOG_MESSAGES[:found_secrets_with_errors])

          raise ::Gitlab::GitAccess::ForbiddenError, message
        when ::Gitlab::SecretDetection::Status::SCAN_TIMEOUT
          # Entire scan timed out, we log and skip the check for now.
          secret_detection_logger.error(message: ERROR_MESSAGES[:scan_timeout_error])
        when ::Gitlab::SecretDetection::Status::INPUT_ERROR
          # Scan failed to invalid input. We skip the check because an input error
          # could be due to not having `blobs` being empty (i.e. no new blobs to scan).
          secret_detection_logger.error(message: ERROR_MESSAGES[:invalid_input_error])
        else
          # Invalid status returned by the scanning service/gem, we don't
          # know how to handle that, so nothing happens and we skip the check.
          secret_detection_logger.error(message: ERROR_MESSAGES[:invalid_scan_status_code_error])
        end
      end

      def revisions
        @revisions ||= changes_access
                        .changes
                        .pluck(:newrev) # rubocop:disable CodeReuse/ActiveRecord -- Array#pluck
                        .reject { |revision| ::Gitlab::Git.blank_ref?(revision) }
                        .compact
      end

      def build_secrets_found_message(results, with_errors: false)
        message = with_errors ? LOG_MESSAGES[:found_secrets_with_errors] : LOG_MESSAGES[:found_secrets]

        results[:commits].each do |sha, paths|
          message += format(LOG_MESSAGES[:finding_message_occurrence_header], { sha: sha })

          paths.each do |path, findings|
            findings.each do |finding|
              message += format(LOG_MESSAGES[:finding_message_occurrence_path], { path: path })
              message += build_finding_message(finding, :commit)
            end
          end
        end

        results[:blobs].compact.each do |_, findings|
          findings.each do |finding|
            message += build_finding_message(finding, :blob)
          end
        end

        message += LOG_MESSAGES[:found_secrets_post_message]
        message += format(
          LOG_MESSAGES[:found_secrets_docs_link],
          {
            path: Rails.application.routes.url_helpers.help_page_url(
              DOCUMENTATION_PATH,
              anchor: DOCUMENTATION_PATH_ANCHOR
            )
          }
        )

        # Commenting these out as the WebIDE is failing on displaying this message due to length.
        # message += LOG_MESSAGES[:skip_secret_detection]
        # message += LOG_MESSAGES[:found_secrets_footer]
        # Also shortened up the found_secrets: message

        message
      end

      def build_finding_message(finding, type)
        case finding.status
        when ::Gitlab::SecretDetection::Status::FOUND
          case type
          when :commit
            build_commit_finding_message(finding)
          when :blob
            build_blob_finding_message(finding)
          end
        when ::Gitlab::SecretDetection::Status::SCAN_ERROR
          format(ERROR_MESSAGES[:failed_to_scan_regex_error], finding.to_h)
        when ::Gitlab::SecretDetection::Status::BLOB_TIMEOUT
          format(ERROR_MESSAGES[:blob_timed_out_error], finding.to_h)
        end
      end

      def build_commit_finding_message(finding)
        format(
          LOG_MESSAGES[:finding_message_occurrence_line],
          {
            line_number: finding.line_number,
            description: finding.description
          }
        )
      end

      def build_blob_finding_message(finding)
        format(LOG_MESSAGES[:finding_message], finding.to_h)
      end

      def transform_findings(response)
        # Let's group the findings by the blob id.
        findings_by_blobs = response.results.group_by(&:blob_id)

        # We create an empty hash for the structure we'll create later as we pull out tree entries.
        findings_by_commits = {}

        # Let's create a set to store ids of blobs found in tree entries.
        blobs_found_with_tree_entries = Set.new

        commits = changes_access.commits.map { |commit| commit.id.match(/[a-f0-9]{40}([a-f0-9]{24})?/).to_s }
        # Scanning had found secrets, let's try to look up their file path and commit id. This can be done
        # by using `GetTreeEntries()` RPC, and cross examining blobs with ones where secrets where found.
        commits.each do |revision|
          # We could try to handle pagination, but it is likely to timeout way earlier given the
          # huge default limit (100000) of entries, so we log an error if we get too many results.
          entries, cursor = ::Gitlab::Git::Tree.tree_entries(
            repository: project.repository,
            sha: revision,
            recursive: true,
            rescue_not_found: false
          )

          # TODO: Handle pagination in the upcoming iterations
          # We don't raise because we could still provide a hint to the user
          # about the detected secrets even without a commit sha/file path information.
          unless cursor.next_cursor.empty?
            secret_detection_logger.error(
              message: format(ERROR_MESSAGES[:too_many_tree_entries_error], { sha: revision })
            )
          end

          # Let's grab the `commit_id` and the `path` for that entry, we use the blob id as key.
          entries.each do |entry|
            # Skip any entry that isn't a blob.
            next if entry.type != :blob

            # Skip if the blob doesn't have any findings.
            next unless findings_by_blobs[entry.id].present?

            new_entry = findings_by_blobs[entry.id].each_with_object({}) do |finding, hash|
              hash[entry.commit_id] ||= {}
              hash[entry.commit_id][entry.path] ||= []
              hash[entry.commit_id][entry.path] << finding
            end

            # Put findings with tree entries inside `findings_by_commits` hash.
            findings_by_commits.merge!(new_entry) do |_commit_sha, existing_findings, new_findings|
              existing_findings.merge!(new_findings)
            end
            # Mark as found with tree entry already.
            blobs_found_with_tree_entries << entry.id
          end
        end

        # Remove blobs that has already been found in a tree entry.
        findings_by_blobs.delete_if { |blob_id, _| blobs_found_with_tree_entries.include?(blob_id) }

        # Return the findings as a hash sorted by commits and blobs (minus ones already found).
        {
          commits: findings_by_commits,
          blobs: findings_by_blobs
        }
      end
    end
  end
end
