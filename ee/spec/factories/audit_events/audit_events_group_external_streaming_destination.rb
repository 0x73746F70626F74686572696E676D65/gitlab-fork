# frozen_string_literal: true

FactoryBot.define do
  factory :audit_events_group_external_streaming_destination,
    class: 'AuditEvents::Group::ExternalStreamingDestination' do
    group
    category { 'http' }
    config { { url: FFaker::Internet.http_url } }
    secret_token { 'a' * 20 }
  end
end
