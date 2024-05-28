# frozen_string_literal: true

FactoryBot.define do
  factory :member_role do
    namespace { association(:group) }
    base_access_level { Gitlab::Access::DEVELOPER }
    read_code { true }
    name { generate(:title) }

    trait(:developer) { base_access_level { Gitlab::Access::DEVELOPER } }
    trait(:maintainer) { base_access_level { Gitlab::Access::MAINTAINER } }
    trait(:reporter) { base_access_level { Gitlab::Access::REPORTER } }
    trait(:guest) { base_access_level { Gitlab::Access::GUEST } }
    trait(:minimal_access) { base_access_level { Gitlab::Access::MINIMAL_ACCESS } }

    Gitlab::CustomRoles::Definition.all.each_value do |attributes|
      trait attributes[:name].to_sym do
        send(attributes[:name].to_sym) { true }
        attributes.fetch(:requirements, []).each do |requirement|
          send(requirement.to_sym) { true }
        end
      end
    end

    # this trait can be used only for self-managed
    trait(:instance) { namespace { nil } }
  end
end
