# frozen_string_literal: true

module Gitlab
  module Email
    ProcessingError = Class.new(StandardError)
    EmailUnparsableError = Class.new(ProcessingError)
    SentNotificationNotFoundError = Class.new(ProcessingError)
    ProjectNotFound = Class.new(ProcessingError)
    EmptyEmailError = Class.new(ProcessingError)
    AutoGeneratedEmailError = Class.new(ProcessingError)
    UserNotFoundError = Class.new(ProcessingError)
    UserBlockedError = Class.new(ProcessingError)
    UserNotAuthorizedError = Class.new(ProcessingError)
    NoteableNotFoundError = Class.new(ProcessingError)
    InvalidRecordError = Class.new(ProcessingError)
    InvalidNoteError = Class.new(InvalidRecordError)
    InvalidIssueError = Class.new(InvalidRecordError)
    InvalidMergeRequestError = Class.new(InvalidRecordError)
    UnknownIncomingEmail = Class.new(ProcessingError)
    InvalidAttachment = Class.new(ProcessingError)
    EmailTooLarge = Class.new(ProcessingError)
    MultipleRecipientsError = Class.new(ArgumentError)
  end
end
