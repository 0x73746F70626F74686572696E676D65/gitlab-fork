# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_checkpoint, class: 'Ai::DuoWorkflows::Checkpoint' do
    workflow { association(:duo_workflows_workflow) }
    checkpoint { { key: 'value' } }
    metadata { { metadata_key: 'metadata value' } }
    sequence(:thread_ts) { |n| (Time.current + n.seconds).to_s }
    parent_ts { (Time.parse(thread_ts) - 1.second).to_s }
    project { association(:project) }
  end
end
