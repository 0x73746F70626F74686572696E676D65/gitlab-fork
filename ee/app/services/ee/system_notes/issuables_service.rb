# frozen_string_literal: true
module EE
  module SystemNotes
    module IssuablesService
      extend ::Gitlab::Utils::Override
      # Called when the health_status of an Issue is changed
      #
      # Example Note text:
      #
      #   "removed the health status"
      #
      #   "changed health status to at risk"
      #
      # Returns the created Note object
      def change_health_status_note(previous_status)
        health_status = noteable.health_status&.humanize(capitalize: false)
        body = if health_status
                 "changed health status to **#{health_status}**"
               else
                 "removed health status **#{previous_status&.humanize(capitalize: false)}**"
               end

        if noteable.is_a?(Issue)
          issue_activity_counter.track_issue_health_status_changed_action(author: author, project: project)
        end

        create_note(NoteSummary.new(noteable, project, author, body, action: 'health_status'))
      end

      # Called when the progress of a WorkItem is changed
      #
      # Example Note text:
      #
      #   "changed progress to 10%"
      #
      # Returns the created Note object
      def change_progress_note
        progress = noteable.progress&.progress

        body = if noteable.progress&.destroyed?
                 "removed the progress **#{progress}%**"
               else
                 "changed progress to **#{progress}%**"
               end

        create_note(NoteSummary.new(noteable, project, author, body, action: 'progress'))
      end

      # Called when the color of a WorkItem is changed
      #
      # Example Note text:
      #
      #   "changed color from `#0052cc` to '#345678'"
      #
      # Returns the created Note object
      def change_color_note(previous_color)
        color = noteable.color&.color
        body = if previous_color
                 "changed color from `#{previous_color}` to `#{color}`"
               elsif noteable.color&.destroyed?
                 "removed color `#{color}`"
               else
                 "set color to `#{color}`"
               end

        create_note(NoteSummary.new(noteable, project, author, body, action: 'color'))
      end

      # Called when the reminder_frequency of a WorkItemProgress is changed
      #
      # Example Note text:
      #
      #   "set a weekly checkin reminder"
      #
      # Returns the created Note object
      def change_checkin_reminder_note
        cadence = noteable.progress&.reminder_frequency

        body = if cadence == 'never'
                 "removed the checkin reminder"
               else
                 "set a **#{cadence.humanize(capitalize: false)}** checkin reminder"
               end

        create_note(NoteSummary.new(noteable, project, author, body, action: 'checkin_reminder'))
      end

      # Called when the an issue is published to a project's
      # status page application
      #
      # Example Note text:
      #
      #   "published this issue to the status page"
      #
      # Returns the created Note object
      def publish_issue_to_status_page
        body = 'published this issue to the status page'

        create_note(NoteSummary.new(noteable, project, author, body, action: 'published'))
      end

      # Called when an issuable is linked as blocking
      #
      # noteable_ref - Referenced noteable object, or array of objects
      #
      # Example Note text:
      #
      #   "marked this issue as blocking gitlab-foss#9001"
      #   "marked this issue as blocking gitlab-foss#9001 and gitlab-foss#9002"
      #   "marked this epic as blocking &9"
      #   "marked this epic as blocking &9, &10, and &11"
      #
      # Returns the created Note object
      def block_issuable(noteable_ref)
        body = block_message(noteable_name, extract_issuable_reference(noteable_ref), 'blocking')

        track_issue_event(:track_issue_related_action)

        create_note(NoteSummary.new(noteable, project, author, body, action: 'relate'))
      end

      # Called when an issuable is linked as a blocked by
      #
      # noteable_ref - Referenced noteable object, or array of objects
      #
      # Example Note text:
      #
      #   "marked this issue as blocked by gitlab-foss#9001"
      #   "marked this issue as blocked by gitlab-foss#9001 and gitlab-foss#9002"
      #   "marked this epic as blocked by &9"
      #   "marked this epic as blocked by &9, &10, and &11"
      #
      # Returns the created Note object
      def blocked_by_issuable(noteable_ref)
        body = block_message(noteable_name, extract_issuable_reference(noteable_ref), 'blocked by')

        track_issue_event(:track_issue_related_action)

        create_note(NoteSummary.new(noteable, project, author, body, action: 'relate'))
      end

      override :track_cross_reference_action
      def track_cross_reference_action
        super

        return unless noteable.is_a?(Epic)

        counter = ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter

        counter.track_epic_cross_referenced(author: author, namespace: noteable.group)
      end

      private

      def block_message(issuable_type, noteable_reference, type)
        "marked this #{issuable_type} as #{type} #{noteable_reference}"
      end
    end
  end
end
