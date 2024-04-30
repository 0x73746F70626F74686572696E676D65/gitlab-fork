# frozen_string_literal: true

FactoryBot.define do
  factory :audit_events_instance_external_streaming_destination,
    class: 'AuditEvents::Instance::ExternalStreamingDestination' do
    category { 'http' }
    config { { url: FFaker::Internet.http_url } }
    secret_token { 'a' * 20 }
  end
end
