# frozen_string_literal: true

FactoryBot.modify do
  factory :work_item do
    trait :requirement do
      association :work_item_type, :default, :requirement
    end

    trait :test_case do
      association :work_item_type, :default, :test_case
    end

    trait :objective do
      association :work_item_type, :default, :objective
    end

    trait :key_result do
      association :work_item_type, :default, :key_result
    end

    trait :epic_with_legacy_epic do
      project { nil }
      association :work_item_type, :default, :epic
      association :namespace, factory: :group
      association :author, factory: :user

      synced_epic do
        association(:epic,
          group: instance.namespace,
          title: title,
          description: description,
          created_at: created_at,
          updated_at: updated_at,
          author: author,
          iid: iid,
          updated_by: updated_by,
          state: state,
          closed_at: closed_at,
          confidential: confidential,
          work_item: instance
        )
      end

      after(:create) do |work_item|
        if work_item.synced_epic
          work_item.synced_epic.update_columns(
            created_at: work_item.created_at,
            updated_at: work_item.updated_at,
            relative_position: work_item.synced_epic.id
          )

          work_item.update_columns(
            relative_position: work_item.synced_epic.id
          )
        end
      end
    end

    trait :satisfied_status do
      association :work_item_type, :default, :requirement

      after(:create) do |work_item|
        create(:test_report, requirement_issue: work_item, state: :passed)
      end
    end

    trait :failed_status do
      association :work_item_type, :default, :requirement

      after(:create) do |work_item|
        create(:test_report, requirement_issue: work_item, state: :failed)
      end
    end

    after(:build) do |work_item|
      next unless work_item.work_item_type.requirement?

      work_item.build_requirement(project: work_item.project)
    end
  end
end
