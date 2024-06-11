# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::RemoteDevelopment::AgentConfig::Main, "Integration", feature_category: :remote_development do
  let(:enabled) { true }
  let(:dns_zone) { 'my-awesome-domain.me' }

  let(:config) do
    {
      remote_development: {
        enabled: enabled,
        dns_zone: dns_zone
      }
    }
  end

  let(:context) { { agent: agent, config: config } }

  subject(:response) do
    described_class.main(context)
  end

  before do
    allow(License).to receive(:feature_available?).with(:remote_development).and_return(true)
  end

  context "when a remote_development_agent_config record does not already exist" do
    let_it_be(:agent) { create(:cluster_agent) }

    context 'when config passed is empty' do
      let(:config) { {} }

      it 'does not create a config record' do
        expect { response }.to not_change { RemoteDevelopment::RemoteDevelopmentAgentConfig.count }

        expect(response).to eq({
          status: :success,
          payload: { skipped_reason: :no_config_file_entry_found }
        })
      end
    end

    context 'when config passed results in updates to the remote_development_agent_config record' do
      it 'creates a config record' do
        expect { response }.to change { RemoteDevelopment::RemoteDevelopmentAgentConfig.count }.by(1)

        expect(response).to eq({
          status: :success,
          payload: { remote_development_agent_config: agent.reload.remote_development_agent_config }
        })
      end
    end

    context 'when config is invalid' do
      let(:dns_zone) { "invalid dns zone" }

      it 'does not create the record and returns error' do
        expect { response }.to not_change { RemoteDevelopment::RemoteDevelopmentAgentConfig.count }

        expect(response).to eq({
          status: :error,
          message: "Agent config update failed: Dns zone contains invalid characters (valid characters: [a-z0-9\\-])",
          reason: :bad_request
        })

        config_instance = agent.reload.remote_development_agent_config
        expect(config_instance).to be_nil
      end
    end
  end

  context "when a remote_development_agent_config record already exists" do
    let_it_be(:agent) { create(:ee_cluster_agent, :with_remote_development_agent_config) }

    context 'when config passed is empty' do
      let(:config) { {} }

      it 'does not create a config record' do
        expect { response }.to not_change { agent.reload.remote_development_agent_config.attributes }

        expect(response).to eq({
          status: :success,
          payload: { skipped_reason: :no_config_file_entry_found }
        })
      end
    end

    context 'when config passed results in updates to the remote_development_agent_config record' do
      it 'updates the config record' do
        expect(response).to eq({
          status: :success,
          payload: { remote_development_agent_config: agent.reload.remote_development_agent_config }
        })

        expect(agent.reload.remote_development_agent_config.dns_zone).to eq(dns_zone)
      end
    end

    context 'when config is invalid' do
      let(:dns_zone) { "invalid dns zone" }

      it 'does not update the record and returns error' do
        expect { response }.to not_change { agent.reload.remote_development_agent_config.attributes }

        expect(response).to eq({
          status: :error,
          message: "Agent config update failed: Dns zone contains invalid characters (valid characters: [a-z0-9\\-])",
          reason: :bad_request
        })
      end
    end

    context "when the agent has associated workspaces" do
      let_it_be(:workspace_1) { create(:workspace, agent: agent, force_include_all_resources: false) }
      let_it_be(:workspace_2) { create(:workspace, agent: agent, force_include_all_resources: false) }

      it 'sets force_include_all_resources to true on all associated workspaces' do
        # sanity check fixture state
        expect(agent.reload.workspaces.all? { |workspace| workspace.force_include_all_resources == false }).to be true

        response

        expect(agent.reload.workspaces.all? { |workspace| workspace.force_include_all_resources == true }).to be true
      end

      context 'when config passed contains a dns_zone update' do
        it 'sets dns_zone on all associated workspaces' do
          response

          expect(agent.reload.workspaces.all? { |workspace| workspace.dns_zone == dns_zone }).to be true
        end
      end

      context 'when associated workspaces cannot be updated' do
        before do
          # rubocop:disable RSpec/AnyInstanceOf -- allow_next_instance_of does not work here
          allow_any_instance_of(RemoteDevelopment::RemoteDevelopmentAgentConfig)
            .to receive_message_chain(:workspaces, :desired_state_not_terminated, :touch_all)
          allow_any_instance_of(RemoteDevelopment::RemoteDevelopmentAgentConfig)
            .to receive_message_chain(:workspaces, :desired_state_not_terminated, :update_all)
              .and_raise(ActiveRecord::ActiveRecordError, "SOME ERROR")
          # rubocop:enable RSpec/AnyInstanceOf -- allow_next_instance_of does not work here
        end

        it 'does not update the workspace records and returns error' do
          expect(response).to eq({
            status: :error,
            message: "Agent config update failed: Error updating associated workspaces with update_all: SOME ERROR",
            reason: :bad_request
          })

          expect(agent.reload.workspaces.all? { |workspace| workspace.force_include_all_resources == false }).to be true
          expect(agent.reload.workspaces.all? { |workspace| workspace.dns_zone != dns_zone }).to be true
        end
      end
    end
  end
end
