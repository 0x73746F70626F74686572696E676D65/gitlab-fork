# frozen_string_literal: true

module EE
  module WorkItems
    module WorkItemsFinder
      extend ::Gitlab::Utils::Override

      # Used to check if epic_and_work_item_associations_unification
      # feature flag is enabled for the group and apply filtering over award emoji
      # unified association. Should be removed with the feature flag.
      override :reaction_emoji_filter_params
      def reaction_emoji_filter_params
        { group: params.group }
      end
    end
  end
end
