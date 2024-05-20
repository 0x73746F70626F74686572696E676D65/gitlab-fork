# frozen_string_literal: true

FactoryBot.define do
  factory :cloud_connector_access, class: 'CloudConnector::Access' do
    data do
      {
        available_services: [
          {
            name: "code_suggestions",
            serviceStartTime: "2024-02-15T00:00:00Z",
            bundledWith: %w[code_suggestions]
          },
          {
            name: "duo_chat",
            serviceStartTime: nil,
            bundledWith: %w[code_suggestions]
          }
        ]
      }
    end
  end
end
