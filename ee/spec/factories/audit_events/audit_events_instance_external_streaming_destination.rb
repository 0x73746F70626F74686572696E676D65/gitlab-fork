# frozen_string_literal: true

FactoryBot.define do
  factory :audit_events_instance_external_streaming_destination,
    class: 'AuditEvents::Instance::ExternalStreamingDestination' do
    category { 'http' }
    config { { url: FFaker::Internet.http_url } }
    secret_token { 'a' * 20 }

    trait :aws do
      category { 'aws' }
      config do
        {
          accessKeyXid: SecureRandom.hex(8),
          bucketName: SecureRandom.hex(8),
          awsRegion: "ap-south-2"
        }
      end
      secret_token { SecureRandom.hex(8) }
    end
  end
end
