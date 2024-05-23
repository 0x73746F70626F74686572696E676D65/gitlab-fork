# frozen_string_literal: true

FactoryBot.define do
  factory :code_suggestions_usage, class: '::Ai::CodeSuggestionsUsage' do
    event { 'code_suggestions_shown' }
    user { build_stubbed(:user) }

    to_create(&:store)

    # Flush data from Redis buffer to ClickHouse
    after(:create) do
      unless Gitlab::ClickHouse.globally_enabled_for_analytics?
        puts "ClickHouse is not enabled globally for analytics. Your factory won't be saved"
      end

      ClickHouse::CodeSuggestionEventsCronWorker.perform_inline
    end

    trait :requested do
      event { 'code_suggestions_requested' }
    end

    trait :shown do
      event { 'code_suggestions_shown' }
    end

    trait :accepted do
      event { 'code_suggestions_accepted' }
    end

    trait :rejected do
      event { 'code_suggestions_rejected' }
    end
  end
end
