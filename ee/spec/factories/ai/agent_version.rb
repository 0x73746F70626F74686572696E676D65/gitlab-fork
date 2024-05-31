# frozen_string_literal: true

FactoryBot.define do
  factory :ai_agent_version, class: '::Ai::AgentVersion' do
    agent { association :ai_agent }
    project { agent.project }
    prompt { 'Prompt text' }
    model { "anthropic-#{::Gitlab::Llm::Anthropic::Client::DEFAULT_INSTANT_MODEL}" }
  end
end
