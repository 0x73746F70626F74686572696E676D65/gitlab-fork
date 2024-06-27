# frozen_string_literal: true

FactoryBot.define do
  factory :gitlab_subscription_add_on, class: 'GitlabSubscriptions::AddOn' do
    name { GitlabSubscriptions::AddOn.names[:code_suggestions] }
    description { GitlabSubscriptions::AddOn.descriptions[:code_suggestions] }

    trait :gitlab_duo_pro do
      name { GitlabSubscriptions::AddOn.names[:code_suggestions] }
    end

    trait :product_analytics do
      name { GitlabSubscriptions::AddOn.names[:product_analytics] }
      description { GitlabSubscriptions::AddOn.descriptions[:product_analytics] }
    end

    trait :duo_enterprise do
      name { GitlabSubscriptions::AddOn.names[:duo_enterprise] }
      description { GitlabSubscriptions::AddOn.descriptions[:duo_enterprise] }
    end
  end
end
