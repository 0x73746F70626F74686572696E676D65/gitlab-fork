# frozen_string_literal: true

module Mutations
  module Notes
    module Create
      # This is a Base class for the Note creation Mutations and is not
      # mounted as a GraphQL mutation itself.
      class Base < Mutations::Notes::Base
        authorize :create_note

        argument :noteable_id,
          ::Types::GlobalIDType[::Noteable],
          required: true,
          description: 'Global ID of the resource to add a note to.'

        argument :body,
          GraphQL::Types::String,
          required: true,
          description: copy_field_description(Types::Notes::NoteType, :body)

        argument :confidential,
          GraphQL::Types::Boolean,
          required: false,
          description: 'Confidentiality flag of a note. Default is false.',
          deprecated: { reason: :renamed, replacement: 'internal', milestone: '15.3' }

        argument :internal,
          GraphQL::Types::Boolean,
          required: false,
          description: 'Internal flag for a note. Default is false.'

        def resolve(args)
          noteable = authorized_find!(id: args[:noteable_id])
          verify_rate_limit!(current_user)

          note = ::Notes::CreateService.new(
            noteable.project,
            current_user,
            create_note_params(noteable, args)
          ).execute

          {
            note: (note if note.persisted?),
            errors: errors_on_object(note)
          }
        end

        private

        def create_note_params(noteable, args)
          {
            noteable: noteable,
            note: args[:body],
            internal: args[:internal] || args[:confidential]
          }
        end

        def verify_rate_limit!(current_user)
          return unless rate_limit_throttled?

          raise Gitlab::Graphql::Errors::ResourceNotAvailable,
            'This endpoint has been requested too many times. Try again later.'
        end

        def rate_limit_throttled?
          rate_limiter = ::Gitlab::ApplicationRateLimiter
          allowlist = Gitlab::CurrentSettings.current_application_settings.notes_create_limit_allowlist

          rate_limiter.throttled?(:notes_create, scope: [current_user], users_allowlist: allowlist)
        end
      end
    end
  end
end
