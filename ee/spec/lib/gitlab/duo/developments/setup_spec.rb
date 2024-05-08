# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::Setup, :real_ai_request, :saas, :gitlab_duo, feature_category: :duo_chat do
  include DuoChatQaEvaluationHelpers
  include RakeHelpers

  let_it_be(:group) { create(:group, path: 'test-group') }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  let(:task) { described_class.new(args) }
  let(:args) { { root_group_path: group.path } }
  let(:rake_task) { instance_double(Rake::Task, invoke: true) }

  subject(:setup) { task.execute }

  before do
    allow(Rake::Task).to receive(:[]).with(any_args).and_return(rake_task)

    stub_env('GITLAB_SIMULATE_SAAS', '1')

    create_current_license_without_expiration(plan: License::ULTIMATE_PLAN)
  end

  it 'can execute GitLab Duo Chat' do
    expect(Rake::Task['gitlab:llm:embeddings:vertex:seed']).to receive(:invoke)

    setup

    question = "How to create an issue in GitLab?"
    response = chat(user, user, { content: question, cache_response: false, request_id: SecureRandom.uuid })

    expect(response[:response_modifier].ai_response.content).to be_present
    expect(response[:response_modifier].errors).to be_empty
  end

  context 'when embedding database already exists' do
    before do
      allow(::Embedding::Vertex::GitlabDocumentation).to receive(:count).and_return(100)
    end

    context 'when group doest not exist' do
      let(:args) { { root_group_path: 'new-path' } }

      it 'creates a new group' do
        expect { setup }.to change { ::Group.count }.by(1)
      end

      context 'when failed to create a group' do
        let(:args) { { root_group_path: '!!!!!' } }

        it 'raises an error' do
          expect { setup }.to raise_error(RuntimeError)
        end
      end
    end

    context 'when group already exists' do
      it 'does not create a new group' do
        expect { setup }.not_to change { ::Group.count }
      end
    end
  end

  context 'with production environment' do
    before do
      allow(::Gitlab).to receive(:dev_or_test_env?).and_return(false)
    end

    it 'raises an error' do
      expect { setup }.to raise_error(RuntimeError)
    end
  end

  context 'when GITLAB_SIMULATE_SAAS is missing' do
    before do
      stub_const('ENV', { 'GITLAB_SIMULATE_SAAS' => nil })
    end

    it 'raises an error' do
      expect { setup }.to raise_error(RuntimeError)
    end
  end

  context 'when Anthropic key is missing' do
    before do
      allow(::Gitlab::CurrentSettings).to receive(:anthropic_api_key).and_return(nil)
    end

    it 'raises an error' do
      expect { setup }.to raise_error(RuntimeError)
    end
  end

  context 'when VertexAI access is not setup' do
    before do
      allow_next_instance_of(::Gitlab::Llm::VertexAi::TokenLoader) do |token_loader|
        allow(token_loader).to receive(:current_token).and_return(nil)
      end
    end

    it 'raises an error' do
      expect { setup }.to raise_error(RuntimeError)
    end
  end

  context 'when embedding database is not configured' do
    before do
      allow(::Gitlab::Database).to receive(:has_config?).with(:embedding).and_return(false)
    end

    it 'raises an error' do
      expect { setup }.to raise_error(RuntimeError)
    end
  end
end
