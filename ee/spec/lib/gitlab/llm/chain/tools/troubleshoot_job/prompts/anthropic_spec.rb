# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::TroubleshootJob::Prompts::Anthropic, feature_category: :duo_chat do
  let(:user) { create(:user) }

  describe '.prompt' do
    it 'returns prompt', :aggregate_failures do
      result = described_class.prompt(
        input: 'question',
        language_info: 'The repo is written in Ruby.',
        selected_text: 'BUILD LOG'
      )
      prompt = result[:prompt]

      expected_system_prompt = <<~PROMPT
        You are a Software engineer's or DevOps engineer's Assistant.
        You can explain the root cause of a GitLab CI verification job code failure from the job log.
        The repo is written in Ruby.
      PROMPT

      expected_user_prompt = <<~PROMPT.chomp
          Below are the job logs surrounded by the xml tag: <log>

          <log>
            BUILD LOG
          <log>

          question

          Think step by step and try to determine why the job failed and explain it so that
          any Software engineer could understand the root cause of the failure.
          Please provide an example fix under the heading "Example Fix".
          Any code blocks in response should be formatted in markdown.
      PROMPT

      expected_prompt = [
        {
          role: :system, content: expected_system_prompt
        },
        {
          role: :user, content: expected_user_prompt
        }
      ]
      expect(prompt).to eq(expected_prompt)
    end
  end
end
