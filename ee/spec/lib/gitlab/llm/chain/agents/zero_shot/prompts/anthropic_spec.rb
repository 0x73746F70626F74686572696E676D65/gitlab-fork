# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic, feature_category: :duo_chat do
  include FakeBlobHelpers

  describe '.prompt' do
    let(:prompt_version) { ::Gitlab::Llm::Chain::Agents::ZeroShot::Executor::PROMPT_TEMPLATE }
    let(:zero_shot_prompt) { ::Gitlab::Llm::Chain::Agents::ZeroShot::Executor::ZERO_SHOT_PROMPT }
    let(:user) { create(:user) }
    let(:user_input) { 'foo?' }
    let(:system_prompt) { nil }
    let(:options) do
      {
        tools_definitions: "tool definitions",
        tool_names: "tool names",
        user_input: user_input,
        agent_scratchpad: "some observation",
        conversation: [
          build(:ai_message, request_id: 'uuid1', role: 'user', content: 'question 1'),
          build(:ai_message, request_id: 'uuid1', role: 'assistant', content: 'response 1'),
          build(:ai_message, request_id: 'uuid1', role: 'user', content: 'question 2'),
          build(:ai_message, request_id: 'uuid1', role: 'assistant', content: 'response 2')
        ],
        prompt_version: prompt_version,
        current_code: "",
        current_resource: "",
        resources: "",
        current_user: user,
        zero_shot_prompt: zero_shot_prompt,
        system_prompt: system_prompt,
        source_template: "source template"
      }
    end

    let(:prompt_text) { "Answer the question as accurate as you can." }

    subject { described_class.prompt(options)[:prompt] }

    it 'returns the prompt format expected by the anthropic messages API' do
      prompt = subject
      prompts_by_role = prompt.group_by { |prompt| prompt[:role] }
      user_prompts = prompts_by_role[:user]
      assistant_prompts = prompts_by_role[:assistant]

      expect(prompt).to be_instance_of(Array)

      expect(prompts_by_role[:system][0][:content]).to include(
        Gitlab::Llm::Chain::Utils::Prompt.default_system_prompt
      )

      expect(user_prompts[0][:content]).to eq("question 1")
      expect(user_prompts[1][:content]).to eq("question 2")
      expect(user_prompts[2][:content]).to eq(user_input)

      expect(prompts_by_role[:system][0][:content]).to include(prompt_text)

      expect(assistant_prompts[0][:content]).to eq("response 1")
      expect(assistant_prompts[1][:content]).to eq("response 2")
    end

    context 'when system prompt is provided' do
      let(:system_prompt) { 'A custom prompt' }
      let(:prompt_version) do
        [
          Gitlab::Llm::Chain::Utils::Prompt.as_system('Some new instructions'),
          Gitlab::Llm::Chain::Utils::Prompt.as_user("Question: %<user_input>s")
        ]
      end

      it 'returns the system prompt' do
        prompt = subject
        prompts_by_role = prompt.group_by { |prompt| prompt[:role] }
        user_prompts = prompts_by_role[:user]
        assistant_prompts = prompts_by_role[:assistant]

        expect(prompt).to be_instance_of(Array)
        expect(prompts_by_role[:system][0][:content]).to include(system_prompt)

        expect(user_prompts[0][:content]).to eq("question 1")
        expect(user_prompts[1][:content]).to eq("question 2")

        expect(user_prompts[2][:content]).to eq(user_input)
        expect(prompts_by_role[:system][0][:content]).to include(prompt_text)

        expect(assistant_prompts[0][:content]).to eq("response 1")
        expect(assistant_prompts[1][:content]).to eq("response 2")
      end
    end

    context 'when role is duplicated in history' do
      let(:options) do
        {
          tools_definitions: "tool definitions",
          tool_names: "tool names",
          user_input: user_input,
          agent_scratchpad: "some observation",
          conversation: [
            build(:ai_message, request_id: 'uuid1', role: 'user', content: 'question 1'),
            build(:ai_message, request_id: 'uuid1', role: 'assistant', content: 'response 1'),
            build(:ai_message, request_id: 'uuid1', role: 'user', content: 'question 2'),
            build(:ai_message, request_id: 'uuid1', role: 'assistant', content: 'duplicated response 1'),
            build(:ai_message, request_id: 'uuid1', role: 'assistant', content: 'duplicated response 2')
          ],
          prompt_version: prompt_version,
          current_code: "",
          current_resource: "",
          resources: "",
          current_user: user,
          zero_shot_prompt: zero_shot_prompt,
          system_prompt: system_prompt,
          source_template: "source template"
        }
      end

      it 'returns last message with role' do
        prompt = subject

        expect(prompt).to be_instance_of(Array)
        expect(prompt).not_to include(hash_including(role: :assistant, content: 'duplicated response 1'))
        expect(prompt).to include(hash_including(role: :assistant, content: 'duplicated response 2'))
      end
    end
  end

  it_behaves_like 'zero shot prompt'
end
