# frozen_string_literal: true

module WorkItems
  module UnifiedAssociations
    module Notes
      extend ActiveSupport::Concern

      included do
        has_many :own_notes, class_name: 'Note', as: :noteable, inverse_of: :noteable
        # rubocop:disable Cop/ActiveRecordDependent -- needed because this is a polymorphic association
        has_many :notes, -> { extending ::WorkItems::UnifiedAssociations::NotesExtension }, inverse_of: :noteable,
          as: :noteable, dependent: :destroy
        # rubocop:enable Cop/ActiveRecordDependent
      end
    end
  end
end
