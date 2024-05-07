# frozen_string_literal: true

module EE
  module Groups
    module Params
      extend ::Gitlab::Utils::Override

      override :group_feature_attributes
      def group_feature_attributes
        return super unless current_group&.licensed_feature_available?(:group_wikis)

        super + [:wiki_access_level]
      end
    end
  end
end
