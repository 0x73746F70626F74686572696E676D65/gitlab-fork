# frozen_string_literal: true

FactoryBot.define do
  factory :gitlab_subscription_add_on_purchase, class: 'GitlabSubscriptions::AddOnPurchase' do
    add_on { association(:gitlab_subscription_add_on) }
    organization { association(:organization, :default) }
    namespace { association(:group) }
    quantity { 1 }
    started_at { 1.day.ago.to_date }
    expires_on { 1.year.from_now.to_date }
    purchase_xid { SecureRandom.hex(16) }
    trial { false }

    trait :active do
      expires_on { 1.year.from_now.to_date }
    end

    trait :trial do
      trial { true }
      expires_on { GitlabSubscriptions::Trials::DuoPro::DURATION.from_now }
    end

    trait :active_trial do
      trial
      active
    end

    trait :expired do
      expires_on { 2.days.ago }
    end

    trait :expired_trial do
      trial
      expired
    end

    trait :gitlab_duo_pro do
      add_on { association(:gitlab_subscription_add_on, :gitlab_duo_pro) }
    end

    trait :product_analytics do
      add_on { association(:gitlab_subscription_add_on, :product_analytics) }
    end

    trait :self_managed do
      namespace { nil }
    end
  end
end
