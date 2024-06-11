# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::RemoteDevelopment::AgentConfig::Updater, feature_category: :remote_development do
  include ResultMatchers

  let(:enabled) { true }
  let(:dns_zone) { 'my-awesome-domain.me' }
  let(:saved_quota) { 5 }
  let(:quota) { 5 }
  let(:network_policy_present) { false }
  let(:default_network_policy_egress) { RemoteDevelopment::AgentConfig::Updater::NETWORK_POLICY_EGRESS_DEFAULT }
  let(:network_policy_egress) { default_network_policy_egress }
  let(:network_policy_enabled) { true }
  let(:network_policy_without_egress) do
    { enabled: network_policy_enabled }
  end

  let(:network_policy_with_egress) do
    {
      enabled: network_policy_enabled,
      egress: network_policy_egress
    }
  end

  let(:network_policy) { network_policy_without_egress }
  let(:gitlab_workspaces_proxy_present) { false }
  let(:gitlab_workspaces_proxy_namespace) { 'gitlab-workspaces' }
  let(:gitlab_workspaces_proxy) do
    { namespace: gitlab_workspaces_proxy_namespace }
  end

  let(:default_default_resources_per_workspace_container) do
    RemoteDevelopment::AgentConfig::Updater::DEFAULT_RESOURCES_PER_WORKSPACE_CONTAINER_DEFAULT
  end

  let(:default_resources_per_workspace_container) { default_default_resources_per_workspace_container }
  let(:default_max_resources_per_workspace) do
    RemoteDevelopment::AgentConfig::Updater::MAX_RESOURCES_PER_WORKSPACE_DEFAULT
  end

  let(:max_resources_per_workspace) { default_max_resources_per_workspace }

  let_it_be(:agent) { create(:cluster_agent) }
  let_it_be(:workspace1) { create(:workspace, force_include_all_resources: false) }
  let_it_be(:workspace2) { create(:workspace, force_include_all_resources: false) }

  let(:config) do
    remote_development_config = {
      enabled: enabled,
      dns_zone: dns_zone
    }
    remote_development_config[:network_policy] = network_policy if network_policy_present
    remote_development_config[:gitlab_workspaces_proxy] = gitlab_workspaces_proxy if gitlab_workspaces_proxy_present
    remote_development_config[:default_resources_per_workspace_container] = default_resources_per_workspace_container
    remote_development_config[:max_resources_per_workspace] = max_resources_per_workspace

    if quota
      remote_development_config[:workspaces_quota] = quota
      remote_development_config[:workspaces_per_user_quota] = quota
    end

    {
      remote_development: remote_development_config
    }
  end

  subject(:result) do
    described_class.update(agent: agent, config: config) # rubocop:disable Rails/SaveBang -- this isn't ActiveRecord
  end

  context 'when config passed is empty' do
    let(:config) { {} }

    it "does not update and returns an ok Result containing a hash indicating update was skipped" do
      expect { result }.to not_change { RemoteDevelopment::RemoteDevelopmentAgentConfig.count }

      expect(result)
        .to be_ok_result(RemoteDevelopment::Messages::AgentConfigUpdateSkippedBecauseNoConfigFileEntryFound.new(
          { skipped_reason: :no_config_file_entry_found }
        ))
    end
  end

  context 'when config passed is not empty' do
    shared_examples 'successful update' do
      it 'creates a config record and returns an ok Result containing the agent config' do
        expect { result }.to change { RemoteDevelopment::RemoteDevelopmentAgentConfig.count }

        config_instance = agent.reload.remote_development_agent_config
        expect(config_instance.enabled).to eq(enabled)
        expect(config_instance.dns_zone).to eq(dns_zone)
        expect(config_instance.network_policy_enabled).to eq(network_policy_enabled)
        expect(config_instance.network_policy_egress.map(&:deep_symbolize_keys)).to eq(network_policy_egress)
        expect(config_instance.gitlab_workspaces_proxy_namespace).to eq(gitlab_workspaces_proxy_namespace)
        expect(config_instance.default_resources_per_workspace_container.deep_symbolize_keys)
          .to eq(default_resources_per_workspace_container)
        expect(config_instance.max_resources_per_workspace.deep_symbolize_keys)
          .to eq(max_resources_per_workspace)
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect(config_instance.workspaces_quota).to eq(saved_quota)
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect(config_instance.workspaces_per_user_quota).to eq(saved_quota)

        expect(result)
          .to be_ok_result(RemoteDevelopment::Messages::AgentConfigUpdateSuccessful.new(
            { remote_development_agent_config: config_instance }
          ))
        expect(config_instance.workspaces).to all(have_attributes(force_include_all_resources: true))
      end
    end

    context 'when a config file is valid' do
      it_behaves_like 'successful update'

      context 'when enabled is not present in the config passed' do
        let(:config) { { remote_development: { dns_zone: dns_zone } } }

        it 'creates a config record with a default context of enabled as false' do
          expect { result }.to change { RemoteDevelopment::RemoteDevelopmentAgentConfig.count }
          expect(result).to be_ok_result
          expect(agent.reload.remote_development_agent_config.enabled).to eq(false)
        end
      end

      context 'when network_policy key is present in the config passed' do
        let(:network_policy_present) { true }

        context 'when network_policy key is empty hash in the config passed' do
          let(:network_policy) { {} }

          it_behaves_like 'successful update'
        end

        context 'when network_policy.enabled is explicitly specified in the config passed' do
          let(:network_policy_enabled) { false }

          it_behaves_like 'successful update'
        end

        context 'when network_policy.egress is explicitly specified in the config passed' do
          let(:network_policy_egress) do
            [
              {
                allow: "0.0.0.0/0",
                except: %w[10.0.0.0/8]
              }
            ].freeze
          end

          let(:network_policy) { network_policy_with_egress }

          it_behaves_like 'successful update'
        end
      end

      context 'when gitlab_workspaces_proxy is present in the config passed' do
        let(:gitlab_workspaces_proxy_present) { true }

        context 'when gitlab_workspaces_proxy is empty hash in the config passed' do
          let(:gitlab_workspaces_proxy) { {} }

          it_behaves_like 'successful update'
        end

        context 'when gitlab_workspaces_proxy.namespace is explicitly specified in the config passed' do
          let(:gitlab_workspaces_proxy_namespace) { 'gitlab-workspaces-specified' }

          it_behaves_like 'successful update'
        end
      end

      context 'when default_resources_per_workspace_container is present in the config passed' do
        context 'when gitlab_workspaces_proxy is empty hash in the config passed' do
          let(:default_resources_per_workspace_container) { {} }

          it_behaves_like 'successful update'
        end

        context 'when default_resources_per_workspace_container is explicitly specified in the config passed' do
          let(:default_resources_per_workspace_container) do
            { limits: { cpu: "500m", memory: "1Gi" }, requests: { cpu: "200m", memory: "0.5Gi" } }
          end

          it_behaves_like 'successful update'
        end
      end

      context 'when max_resources_per_workspace is present in the config passed' do
        context 'when gitlab_workspaces_proxy is empty hash in the config passed' do
          let(:max_resources_per_workspace) { {} }

          it_behaves_like 'successful update'
        end

        context 'when max_resources_per_workspace is explicitly specified in the config passed' do
          let(:max_resources_per_workspace) do
            { limits: { cpu: "500m", memory: "1Gi" }, requests: { cpu: "200m", memory: "0.5Gi" } }
          end

          it_behaves_like 'successful update'
        end
      end

      context 'when workspace quotas are not explicitly specified in the config passed' do
        let(:quota) { nil }
        let(:saved_quota) { -1 }

        it_behaves_like 'successful update'
      end

      context 'when the dns_zone has been updated' do # rubocop:disable RSpec/MultipleMemoizedHelpers -- Need helpers for scenarios
        let_it_be(:old_dns_zone) { 'old-dns-zone.test' }
        let_it_be(:new_dns_zone) { 'new-dns-zone.test' }
        let_it_be(:dns_zone) { new_dns_zone }

        let_it_be(:non_terminated_workspace) do
          create(
            :workspace,
            agent: agent,
            actual_state: RemoteDevelopment::Workspaces::States::RUNNING,
            desired_state: RemoteDevelopment::Workspaces::States::RUNNING,
            dns_zone: old_dns_zone,
            force_include_all_resources: false
          )
        end

        let_it_be(:terminated_workspace) do
          create(
            :workspace,
            agent: agent,
            actual_state: RemoteDevelopment::Workspaces::States::RUNNING,
            desired_state: RemoteDevelopment::Workspaces::States::TERMINATED,
            dns_zone: old_dns_zone,
            force_include_all_resources: false
          )
        end

        let_it_be(:new_config) do
          {
            remote_development: {
              enabled: true,
              dns_zone: new_dns_zone
            }
          }
        end

        before do
          described_class.update(agent: agent, config: config) # rubocop:disable Rails/SaveBang -- this isn't ActiveRecord
        end

        it 'updates the dns_zone' do
          expect { result }.not_to change { RemoteDevelopment::RemoteDevelopmentAgentConfig.count }
          config_instance = agent.reload.remote_development_agent_config
          expect(result)
            .to be_ok_result(RemoteDevelopment::Messages::AgentConfigUpdateSuccessful.new(
              { remote_development_agent_config: config_instance }
            ))
          expect(config_instance.dns_zone).to eq(new_dns_zone)
        end

        context 'when workspaces are present' do # rubocop:disable RSpec/MultipleMemoizedHelpers -- Need helpers for scenarios
          it 'updates workspaces in a non-terminated state to force update' do
            expect { result }.not_to change { RemoteDevelopment::RemoteDevelopmentAgentConfig.count }
            config_instance = agent.reload.remote_development_agent_config
            expect(result)
              .to be_ok_result(RemoteDevelopment::Messages::AgentConfigUpdateSuccessful.new(
                { remote_development_agent_config: config_instance }
              ))
            expect(non_terminated_workspace.reload.force_include_all_resources).to eq(true)
          end

          it 'updates the dns_zone of a workspace with desired_state non-terminated' do
            expect { result }.not_to change { RemoteDevelopment::RemoteDevelopmentAgentConfig.count }
            config_instance = agent.reload.remote_development_agent_config
            expect(result)
              .to be_ok_result(RemoteDevelopment::Messages::AgentConfigUpdateSuccessful.new(
                { remote_development_agent_config: config_instance }
              ))
            expect(non_terminated_workspace.reload.dns_zone).to eq(new_dns_zone)
          end

          it 'does not update workspaces with desired_state terminated' do
            expect { result }.not_to change { RemoteDevelopment::RemoteDevelopmentAgentConfig.count }
            config_instance = agent.reload.remote_development_agent_config
            expect(result)
              .to be_ok_result(RemoteDevelopment::Messages::AgentConfigUpdateSuccessful.new(
                { remote_development_agent_config: config_instance }
              ))
            expect(terminated_workspace.reload.force_include_all_resources).to eq(false)
          end

          context 'when workspaces update_all fails' do # rubocop:disable RSpec/MultipleMemoizedHelpers -- Need helpers for scenarios
            before do
              # rubocop:disable RSpec/AnyInstanceOf -- allow_next_instance_of does not work here
              allow_any_instance_of(RemoteDevelopment::RemoteDevelopmentAgentConfig)
                .to receive_message_chain(:workspaces, :desired_state_not_terminated, :touch_all)
              allow_any_instance_of(RemoteDevelopment::RemoteDevelopmentAgentConfig)
                .to receive_message_chain(:workspaces, :desired_state_not_terminated, :update_all)
                      .and_raise(ActiveRecord::ActiveRecordError, "SOME ERROR")
              # rubocop:enable RSpec/AnyInstanceOf
            end

            it 'returns an error result' do
              expect { result }.not_to change { RemoteDevelopment::RemoteDevelopmentAgentConfig.count }
              expect(result).to be_err_result do |message|
                expect(message).to be_a(RemoteDevelopment::Messages::AgentConfigUpdateFailed)
                message.content => { details: String => details }
                expect(details).to eq(
                  "Error updating associated workspaces with update_all: SOME ERROR"
                )
              end
              expect(terminated_workspace.reload.force_include_all_resources).to eq(false)
            end
          end
        end
      end
    end

    context 'when config file is invalid' do
      context 'when dns_zone is invalid' do
        let(:dns_zone) { "invalid dns zone" }

        it 'does not create the record and returns error' do
          expect { result }.to not_change { RemoteDevelopment::RemoteDevelopmentAgentConfig.count }
          expect(agent.reload.remote_development_agent_config).to be_nil

          expect(result).to be_err_result do |message|
            expect(message).to be_a(RemoteDevelopment::Messages::AgentConfigUpdateFailed)
            message.content => { errors: ActiveModel::Errors => errors }
            expect(errors.full_messages.join(', ')).to match(/dns zone/i)
          end
        end
      end
    end
  end
end
