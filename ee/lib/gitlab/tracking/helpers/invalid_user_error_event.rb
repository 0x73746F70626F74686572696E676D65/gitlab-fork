# frozen_string_literal: true

module Gitlab
  module Tracking
    module Helpers
      module InvalidUserErrorEvent
        def track_invalid_user_error(user, tracking_label)
          user.errors.full_messages.each do |message|
            Gitlab::Tracking.event(
              'Gitlab::Tracking::Helpers::InvalidUserErrorEvent',
              "track_#{tracking_label}_error",
              label: message.parameterize.underscore
            )
          end
        end
      end
    end
  end
end
