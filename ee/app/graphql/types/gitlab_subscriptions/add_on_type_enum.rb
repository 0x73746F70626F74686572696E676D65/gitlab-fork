# frozen_string_literal: true

module Types
  module GitlabSubscriptions
    class AddOnTypeEnum < BaseEnum
      graphql_name 'GitlabSubscriptionsAddOnType'
      description 'Types of add-ons'

      value 'CODE_SUGGESTIONS', value: :code_suggestions, description: 'GitLab Duo Pro seat add-on.'
    end
  end
end
