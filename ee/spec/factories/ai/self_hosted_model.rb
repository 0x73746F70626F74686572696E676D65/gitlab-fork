# frozen_string_literal: true

FactoryBot.define do
  factory :ai_self_hosted_model, class: '::Ai::SelfHostedModel' do
    endpoint { 'http://localhost:11434/v1' }
    model { :mistral }
    name { 'mistral-7b-ollama-api' }
  end
end
