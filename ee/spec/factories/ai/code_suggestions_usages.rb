# frozen_string_literal: true

FactoryBot.define do
  factory :code_suggestions_usage, class: '::Ai::CodeSuggestionsUsage' do
    event { 'code_suggestion_shown_in_ide' }
    user { build_stubbed(:user) }
    language { 'ruby' }
    suggestion_size { 1 }
    unique_tracking_id { SecureRandom.hex.slice(0, 20) }

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
      event { 'code_suggestion_shown_in_ide' }
    end

    trait :accepted do
      event { 'code_suggestion_accepted_in_ide' }
    end

    trait :rejected do
      event { 'code_suggestion_rejected_in_ide' }
    end
  end
end
