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

    [
      :admin_cicd_variables,
      :admin_compliance_framework,
      :admin_merge_request,
      :admin_push_rules,
      :admin_terraform_state,
      :admin_web_hook,
      :manage_deploy_tokens,
      :manage_group_access_tokens,
      :manage_merge_request_settings,
      :manage_project_access_tokens,
      :read_code,
      :read_dependency,
      :read_vulnerability,
      :remove_group
    ].each do |permission|
      trait permission do
        send(permission) { true }
      end
    end

    trait :admin_vulnerability do
      admin_vulnerability { true }
      read_vulnerability { true }
    end

    # this trait can be used only for self-managed
    trait(:instance) { namespace { nil } }
  end
end
