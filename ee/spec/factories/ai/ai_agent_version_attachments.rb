# frozen_string_literal: true

FactoryBot.define do
  factory :ai_agent_version_attachment, class: '::Ai::AgentVersionAttachment' do
    version { association :ai_agent_version }
    file { association :ai_vectorizable_file }
    project
  end
end
