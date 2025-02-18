# frozen_string_literal: true

FactoryBot.modify do
  factory :issue do
    trait :published do
      after(:create) do |issue|
        issue.create_status_page_published_incident!
      end
    end

    trait :with_sla do
      issuable_sla
    end

    trait :with_synced_epic do
      project { nil }
      association :namespace, factory: :group
      association :author, factory: :user
      association :work_item_type, :default, :epic
      synced_epic do
        association(:epic,
          group: namespace,
          title: title,
          description: description,
          created_at: created_at,
          updated_at: updated_at,
          author: author,
          updated_by: updated_by,
          state: state,
          confidential: confidential
        )
      end

      after(:create) do |issue, _|
        issue.synced_epic.update!(iid: issue.iid, created_at: issue.created_at)
      end
    end
  end
end

FactoryBot.define do
  factory :requirement, parent: :issue do
    association :work_item_type, :default, :requirement
  end
end

FactoryBot.define do
  factory :quality_test_case, parent: :issue do
    association :work_item_type, :default, :test_case
  end
end
