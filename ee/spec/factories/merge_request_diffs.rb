# frozen_string_literal: true

FactoryBot.modify do
  factory :external_merge_request_diff do
    trait(:checksummed) do
      association :merge_request_diff_detail, :checksummed, strategy: :build
    end

    trait(:checksum_failure) do
      association :merge_request_diff_detail, :checksum_failure, strategy: :build
    end

    trait(:verification_succeeded) do
      verification_checksum { 'abc' }
      verification_state { ::MergeRequestDiff.verification_state_value(:verification_succeeded) }
    end

    trait(:verification_failed) do
      verification_failure { 'Could not calculate the checksum' }
      verification_state { ::MergeRequestDiff.verification_state_value(:verification_failed) }

      #
      # Geo::VerifiableReplicator#after_verifiable_update tries to verify
      # the replicable async and marks it as verification pending when the
      # model record is created/updated.
      #
      after(:create) do |instance, _|
        instance.verification_failure = 'Could not calculate the checksum'
        instance.verification_state = ::MergeRequestDiff.verification_state_value(:verification_started)
        instance.verification_failed!
      end
    end
  end
end
