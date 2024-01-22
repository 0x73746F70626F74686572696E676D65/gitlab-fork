# frozen_string_literal: true

module Ci
  module Runners
    # Sends a CSV report containing the runner usage for a given period
    #   (based on ClickHouse's ci_used_minutes_mv view)
    #
    class SendUsageCsvService
      # @param [User] current_user The user performing the reporting
      # @param [Symbol] runner_type The type of runners to report on, or nil to report on all types
      # @param [Date] from_date The start date of the period to examine
      # @param [Date] to_date The end date of the period to examine
      # @param [Integer] max_project_count The maximum number of projects in the report. All others will be folded
      #   into an 'Other projects' entry
      def initialize(current_user:, runner_type:, from_date:, to_date:, max_project_count:)
        @current_user = current_user
        @runner_type = runner_type
        @from_date = from_date
        @to_date = to_date
        @max_project_count = max_project_count
      end

      def execute
        Gitlab::InternalEvents.track_event('export_runner_usage_by_project_as_csv', user: @current_user)

        result = process_csv
        return result if result.error?

        send_email(result)
        log_audit_event(message: 'Sent email with runner usage CSV')

        ServiceResponse.success(payload: result.payload.slice(:status))
      end

      private

      def process_csv
        GenerateUsageCsvService.new(
          @current_user,
          runner_type: @runner_type,
          from_date: @from_date,
          to_date: @to_date,
          max_project_count: @max_project_count
        ).execute
      end

      def send_email(result)
        Notify.runner_usage_by_project_csv_email(
          user: @current_user, from_date: @from_date, to_date: @to_date,
          csv_data: result.payload[:csv_data], export_status: result.payload[:status]
        ).deliver_now
      end

      def log_audit_event(message:)
        audit_context = {
          name: 'ci_runner_usage_export',
          author: @current_user,
          target: ::Gitlab::Audit::NullTarget.new,
          scope: Gitlab::Audit::InstanceScope.new,
          message: message,
          additional_details: {
            runner_type: @runner_type,
            from_date: @from_date.iso8601,
            to_date: @to_date.iso8601
          }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
