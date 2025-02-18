# frozen_string_literal: true

FactoryBot.define do
  factory :audit_events_group_external_streaming_destination,
    class: 'AuditEvents::Group::ExternalStreamingDestination' do
    group
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

    trait :gcp do
      category { 'gcp' }
      config do
        {
          googleProjectIdName: "#{FFaker::Lorem.word.downcase}-#{SecureRandom.hex(4)}",
          clientEmail: FFaker::Internet.safe_email,
          logIdName: SecureRandom.hex(4)
        }
      end
      secret_token { OpenSSL::PKey::RSA.new(4096).to_pem }
    end
  end
end
