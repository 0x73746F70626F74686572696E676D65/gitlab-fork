# frozen_string_literal: true

module Gitlab
  module Email
    module Handler
      module EE
        class ServiceDeskHandler < BaseHandler
          include ReplyProcessing

          def can_handle?
            ::EE::Gitlab::ServiceDesk.enabled? && service_desk_key.present?
          end

          def execute
            raise ProjectNotFound if project.nil?

            create_issue!
            send_thank_you_email! if from_address
          end

          def metrics_params
            super.merge(project: project&.full_path)
          end

          private

          # mail key should end in `-` ie: `h5bp-html5-boilerplate-8-`
          # but continue to support legacy style ie: `h5bp/html5-boilerplate`
          def service_desk_key
            return unless mail_key && (mail_key.end_with?('-') || mail_key.include?('/') && !mail_key.include?('+'))

            mail_key
          end

          def extract_project_id(key)
            key.split('-').last.to_i
          end

          # rubocop: disable CodeReuse/ActiveRecord
          def project
            return @project if instance_variable_defined?(:@project)

            found_project = Project.where(service_desk_enabled: true)
            found_project = if mail_key.end_with?('-')
                              found_project.find_by_id(extract_project_id(service_desk_key))
                            else
                              found_project.find_by_full_path(service_desk_key)
                            end

            # found_project =
            #   Project.where(service_desk_enabled: true)
            #     .find_by_full_path(service_desk_key)

            @project = found_project&.service_desk_enabled? ? found_project : nil
          end
          # rubocop: enable CodeReuse/ActiveRecord

          def create_issue!
            # NB: the support bot is specifically forbidden
            # from mentioning any entities, or from using
            # slash commands.
            @issue = Issues::CreateService.new(
              project,
              User.support_bot,
              title: issue_title,
              description: message,
              confidential: true,
              service_desk_reply_to: from_address
            ).execute

            raise InvalidIssueError unless @issue.persisted?
          end

          def send_thank_you_email!
            Notify.service_desk_thank_you_email(@issue.id).deliver_later!
          end

          def from_address
            (mail.reply_to || []).first || mail.from.first || mail.sender
          end

          def issue_title
            from = "(from #{from_address})" if from_address

            "Service Desk #{from}: #{mail.subject}"
          end
        end
      end
    end
  end
end
