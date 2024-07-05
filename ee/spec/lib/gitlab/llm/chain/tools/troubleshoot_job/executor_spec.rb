# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::TroubleshootJob::Executor, feature_category: :continuous_integration do
  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:build) { create(:ci_build, :failed, :trace_live, project: project) }
  let(:stream_response_handler) { nil }
  let(:input) { 'user input' }
  let(:options) { { input: input } }
  let(:command) { nil }
  let(:prompt_class) { Gitlab::Llm::Chain::Tools::TroubleshootJob::Prompts::Anthropic }

  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user,
      container: nil,
      resource: build,
      ai_request: ai_request_double
    )
  end

  subject(:tool) do
    described_class.new(
      context: context,
      options: options,
      stream_response_handler: stream_response_handler,
      command: command
    )
  end

  RSpec.shared_context 'with repo languages' do
    before do
      allow(project).to receive(:repository_languages).and_return(
        repository_languages.map do |lang|
          instance_double(RepositoryLanguage, name: lang)
        end
      )
    end
  end

  describe '#name' do
    it 'returns the correct tool name' do
      expect(described_class::NAME).to eq('TroubleshootJob')
    end

    it 'returns the correct human-readable name' do
      expect(described_class::HUMAN_NAME).to eq('Troubleshoot Job')
    end
  end

  describe '#description' do
    it 'returns the correct description' do
      expect(described_class::DESCRIPTION).to include('Useful tool to troubleshoot job-related issues.')
    end
  end

  describe '#resource_name' do
    it 'returns the correct description' do
      expect(described_class::RESOURCE_NAME).to include('Ci::Build')
    end
  end

  describe '#execute' do
    context 'when the user is authorized' do
      include_context 'with stubbed LLM authorizer', allowed: true

      before do
        allow(user).to receive(:can?).and_call_original
        allow(user).to receive(:can?).with(:read_build, build).and_return(true)
        allow(user).to receive(:can?).with(:read_build_trace, build).and_return(true)
        allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive_message_chain(:context, :allowed?).and_return(true)
        allow(tool).to receive(:provider_prompt_class).and_return(prompt_class)
      end

      it 'performs the troubleshooting' do
        expect(tool).to receive(:request).and_return('Troubleshooting response')
        expect(tool.execute.content).to eq('Troubleshooting response')
      end

      context 'with repository languages' do
        include_context 'with repo languages'

        let(:repository_languages) { %w[C C++] }

        it 'calls prompt with correct params' do
          allow(tool).to receive(:provider_prompt_class).and_return(prompt_class)
          expect(prompt_class).to receive(:prompt).with(a_hash_including(
            input: input,
            language_info: "The repository code is written in C and C++.",
            selected_text: build.trace.raw
          ))

          tool.execute
        end
      end

      context 'when the feature is disabled' do
        before do
          stub_feature_flags(root_cause_analysis_duo: false)
        end

        it 'returns an error message' do
          expect(tool.execute.content).to eq('This feature is not enabled yet.')
        end
      end

      context 'when the job is not failed' do
        let(:build) { create(:ci_build, :running, project: project) }

        it 'returns an error message' do
          content = tool.execute.content

          expect(content).to include('This command is used for troubleshooting jobs')
          expect(content).to include('failed job')
        end
      end

      context 'when the resource is not a Ci::Build' do
        let(:context) do
          Gitlab::Llm::Chain::GitlabContext.new(
            current_user: user,
            container: nil,
            resource: project,
            ai_request: nil
          )
        end

        before do
          allow(user).to receive(:can?).with(:read_build_trace, project).and_return(true)
        end

        it 'returns an error message' do
          expect(tool.execute.content).to include('This command is used for troubleshooting jobs')
        end
      end
    end

    context 'when the user is not authorized' do
      include_context 'with stubbed LLM authorizer', allowed: false

      before do
        allow(tool).to receive(:provider_prompt_class).and_return(
          ::Gitlab::Llm::Chain::Tools::TroubleshootJob::Prompts::Anthropic
        )
        allow(user).to receive(:can?).with(:read_build_trace, build).and_return(false)
      end

      it 'returns an error message' do
        expect(tool.execute.content).to include(
          "you don't have access to them, or your session has expired."
        )
      end
    end

    describe '#job_log' do
      context 'when the job is present and failed' do
        it 'returns the job trace' do
          expect(tool.send(:job_log)).to eq(build.trace.raw)
        end
      end
    end

    describe '#language_info' do
      include_context 'with repo languages'

      context 'without languages' do
        let(:repository_languages) { [] }

        it 'returns an empty string' do
          expect(tool.send(:language_info)).to eq('')
        end
      end

      context 'when more than one language' do
        let(:repository_languages) { %w[Ruby JavaScript Go] }

        it 'returns the correct language information' do
          expect(tool.send(:language_info)).to eq('The repository code is written in Ruby, JavaScript and Go.')
        end
      end

      context 'with two languages' do
        let(:repository_languages) { %w[JavaScript Go] }

        it 'returns the correct language information' do
          expect(tool.send(:language_info)).to eq('The repository code is written in JavaScript and Go.')
        end
      end

      context 'when one language' do
        let(:repository_languages) { %w[Ruby] }

        it 'returns the correct language information' do
          expect(tool.send(:language_info)).to eq('The repository code is written in Ruby.')
        end
      end
    end
  end
end
