# frozen_string_literal: true

module EE
  module Resolvers
    module GroupsResolver
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        argument :marked_for_deletion_on, ::Types::DateType,
          required: false,
          description: 'Date when the group was marked for deletion.'
      end
    end
  end
end
