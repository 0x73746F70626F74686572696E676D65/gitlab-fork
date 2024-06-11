# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::SlashCommand, feature_category: :duo_chat do
  let(:content) { '/explain' }
  let(:tools) { Gitlab::Llm::Completions::Chat::COMMAND_TOOLS }
  let(:message) do
    build(:ai_chat_message, user: instance_double(User), resource: nil, request_id: 'uuid', content: content)
  end

  describe '.for' do
    subject { described_class.for(message: message, tools: tools) }

    it { is_expected.to be_an_instance_of(described_class) }

    context 'when command is unknown' do
      let(:content) { '/something' }

      it { is_expected.to be_nil }
    end

    context 'when tools are empty' do
      let(:tools) { [] }

      it { is_expected.to be_nil }
    end

    context 'when request comes from the Web' do
      let(:user_agent) { 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)' }
      let(:message) do
        build(:ai_chat_message, user: instance_double(User), resource: nil, request_id: 'uuid', content: content,
          user_agent: user_agent, referer_url: referer_url)
      end

      let(:referer_url) { 'http://example.com/project' }

      it 'returns web as client source' do
        is_expected
          .to be_an_instance_of(described_class)
          .and have_attributes(client_source: 'web')
      end

      context 'when request comes from the Web IDE' do
        let(:referer_url) { "#{Gitlab.config.gitlab.base_url}/-/ide/project" }

        it 'returns webide as client source' do
          is_expected
            .to be_an_instance_of(described_class)
            .and have_attributes(client_source: 'webide')
        end
      end
    end

    context 'when request comes from VS Code' do
      let(:message) do
        build(:ai_chat_message, user: instance_double(User), resource: nil, request_id: 'uuid', content: content,
          user_agent: user_agent)
      end

      let(:user_agent) { 'vs-code-gitlab-workflow/3.11.1 VSCode/1.52.1 Node.js/12.14.1 (darwin; x64)' }

      it 'returns vscode as client source' do
        is_expected
          .to be_an_instance_of(described_class)
          .and have_attributes(client_source: 'vscode')
      end
    end
  end

  describe '#prompt_options' do
    let(:user_input) { nil }
    let(:instruction_with_input) { 'explain %<input>s in the code' }
    let(:params) do
      {
        name: content,
        user_input: user_input,
        tool: nil,
        command_options: {
          instruction: 'explain the code',
          instruction_with_input: instruction_with_input
        }
      }
    end

    subject { described_class.new(**params).prompt_options }

    it { is_expected.to eq({ input: 'explain the code' }) }

    context 'when user input is present' do
      let(:user_input) { 'method params' }

      it { is_expected.to eq({ input: 'explain method params in the code' }) }

      context 'when instruction_with_input is not part of command definition' do
        let(:instruction_with_input) { nil }

        it { is_expected.to eq({ input: 'explain the code' }) }
      end
    end
  end
end
