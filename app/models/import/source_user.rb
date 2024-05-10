# frozen_string_literal: true

module Import
  class SourceUser < ApplicationRecord
    self.table_name = 'import_source_users'

    belongs_to :placeholder_user, class_name: 'User', optional: true
    belongs_to :reassign_to_user, class_name: 'User', optional: true
    belongs_to :reassigned_by_user, class_name: 'User', optional: true
    belongs_to :namespace

    validates :namespace_id, :import_type, :source_hostname, :source_user_identifier, :status, presence: true

    scope :for_namespace, ->(namespace_id) { where(namespace_id: namespace_id) }

    state_machine :status, initial: :pending_assignment do
      state :pending_assignment, value: 0
      state :awaiting_approval, value: 1
      state :rejected, value: 2
      state :failed, value: 3
      state :completed, value: 4

      event :cancel_assignment do
        transition [:awaiting_approval, :rejected] => :pending_assignment
      end

      event :accept do
        transition awaiting_approval: :completed
      end

      event :reject do
        transition awaiting_approval: :rejected
      end

      after_transition any => [:pending_assignment, :rejected] do |status|
        status.update!(reassign_to_user: nil)
      end
    end

    def self.find_source_user(source_user_identifier:, namespace:, source_hostname:, import_type:)
      return unless namespace

      find_by(
        source_user_identifier: source_user_identifier,
        namespace_id: namespace.id,
        source_hostname: source_hostname,
        import_type: import_type
      )
    end
  end
end
