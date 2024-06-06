# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::Workspace, feature_category: :remote_development do
  let_it_be(:user) { create(:user) }
  let_it_be(:agent, reload: true) { create(:ee_cluster_agent, :with_remote_development_agent_config) }
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

  let(:desired_state) { ::RemoteDevelopment::Workspaces::States::STOPPED }

  subject(:workspace) do
    create(:workspace,
      user: user, agent: agent, project: project,
      personal_access_token: personal_access_token, desired_state: desired_state)
  end

  describe 'associations' do
    context "for has_one" do
      it { is_expected.to have_one(:remote_development_agent_config) }
    end

    context "for has_many" do
      it { is_expected.to have_many(:workspace_variables) }
    end

    context "for belongs_to" do
      it { is_expected.to belong_to(:user) }
      it { is_expected.to belong_to(:personal_access_token) }

      it do
        is_expected
          .to belong_to(:agent)
                .class_name('Clusters::Agent')
                .with_foreign_key(:cluster_agent_id)
                .inverse_of(:workspaces)
      end
    end

    context "when from factory" do
      it 'has correct associations from factory' do
        expect(workspace.user).to eq(user)
        expect(workspace.project).to eq(project)
        expect(workspace.agent).to eq(agent)
        expect(workspace.personal_access_token).to eq(personal_access_token)
        expect(workspace.remote_development_agent_config).to eq(agent.remote_development_agent_config)
        expect(agent.remote_development_agent_config.workspaces.first).to eq(workspace)
        expect(workspace.url_prefix).to eq("60001-#{workspace.name}")
        expect(workspace.dns_zone).to eq(agent.remote_development_agent_config.dns_zone)
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect(workspace.url_query_string).to eq("folder=dir%2Ffile")
      end
    end
  end

  describe '#url' do
    subject(:workspace) { build(:workspace) }

    it 'returns calculated url' do
      expect(workspace.url).to eq("https://60001-#{workspace.name}.#{agent.remote_development_agent_config.dns_zone}?folder=dir%2Ffile")
    end
  end

  describe '#devfile_web_url' do
    subject(:workspace) { build(:workspace) }

    it 'returns web url to devfile' do
      # noinspection HttpUrlsUsage - suppress RubyMine warning for insecure http link.
      expect(workspace.devfile_web_url).to eq("http://#{Gitlab.config.gitlab.host}/#{workspace.project.path_with_namespace}/-/blob/main/.devfile.yaml")
    end
  end

  describe '.before_save' do
    describe 'when creating new record', :freeze_time do
      # NOTE: The workspaces factory overrides the desired_state_updated_at to be earlier than
      #       the current time, so we need to use build here instead of create here to test
      #       the callback which sets the desired_state_updated_at to current time upon creation.
      subject(:workspace) { build(:workspace, user: user, agent: agent, project: project) }

      it 'sets desired_state_updated_at' do
        workspace.save!
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect(workspace.desired_state_updated_at).to eq(Time.current)
      end
    end

    describe 'when updating desired_state' do
      it 'sets desired_state_updated_at' do
        expect { workspace.update!(desired_state: ::RemoteDevelopment::Workspaces::States::RUNNING) }.to change {
          workspace.desired_state_updated_at
        }
      end
    end

    describe 'when updating a field other than desired_state' do
      it 'does not set desired_state_updated_at' do
        expect { workspace.update!(actual_state: ::RemoteDevelopment::Workspaces::States::RUNNING) }.not_to change {
          workspace.desired_state_updated_at
        }
      end
    end
  end

  describe 'validations' do
    context "on max_hours_before_termination" do
      let(:limit) { 42 }

      before do
        allow(RemoteDevelopment::Settings)
          .to receive(:get_single_setting).with(:max_hours_before_termination_limit) { limit }
      end

      it 'validates max_hours_before_termination is no more than limit specified by settings' do
        workspace.max_hours_before_termination = limit
        expect(workspace).to be_valid

        workspace.max_hours_before_termination = limit + 1
        expect(workspace).not_to be_valid
      end
    end

    context "on editor" do
      it 'validates editor is webide' do
        workspace.editor = 'not-webide'
        expect(workspace).not_to be_valid
      end
    end

    context 'on remote_development_agent_config' do
      context 'when no config is present' do
        let(:agent_with_no_remote_development_config) { create(:cluster_agent) }

        subject(:invalid_workspace) do
          build(:workspace, user: user, agent: agent_with_no_remote_development_config, project: project)
        end

        it 'validates presence of agent.remote_development_agent_config' do
          # sanity check of fixture
          expect(agent_with_no_remote_development_config.remote_development_agent_config).not_to be_present

          expect(invalid_workspace).not_to be_valid
          expect(invalid_workspace.errors[:agent])
            .to include('for Workspace must have an associated RemoteDevelopmentAgentConfig')
        end

        it "is only validated on create" do
          invalid_workspace.save(validate: false) # rubocop:disable Rails/SaveBang -- intentional to test validation
          invalid_workspace.valid?
          expect(invalid_workspace.errors[:agent]).to be_blank
        end
      end

      context 'when a config is present' do
        subject(:workspace) do
          build(:workspace, user: user, agent: agent, project: project)
        end

        context 'when agent is enabled' do
          before do
            agent.remote_development_agent_config.enabled = true
          end

          it 'validates presence of agent.remote_development_agent_config' do
            expect(workspace).to be_valid
          end
        end

        context 'when agent is disabled' do
          before do
            agent.remote_development_agent_config.enabled = false
          end

          it 'validates agent.remote_development_agent_config is enabled' do
            expect(workspace).not_to be_valid
            expect(workspace.errors[:agent])
              .to include("must have the 'enabled' flag set to true")
          end

          it "is only validated on create" do
            workspace.save(validate: false) # rubocop:disable Rails/SaveBang -- intentional to test validation
            workspace.valid?
            expect(workspace.errors[:agent]).to be_blank
          end
        end
      end
    end

    context 'on dns_zone' do
      subject(:workspace) do
        build(:workspace, user: user, agent: agent, project: project)
      end

      context 'when dns_zone matches config dns_zone' do
        before do
          # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
          workspace.dns_zone = 'zone1'
          # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
          agent.remote_development_agent_config.dns_zone = 'zone1'
        end

        it 'validates presence of agent.remote_development_agent_config' do
          expect(workspace).to be_valid
        end
      end

      context 'when dns_zone does not match config dns_zone' do
        before do
          workspace.dns_zone = 'zone1'
          # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
          agent.remote_development_agent_config.dns_zone = 'zone2'
        end

        context "when workspace is in desired_state Terminated" do
          before do
            workspace.desired_state = ::RemoteDevelopment::Workspaces::States::TERMINATED
          end

          it 'does not validate dns_zone matches agent.remote_development_agent_config.dns_zone' do
            expect(workspace).to be_valid
          end
        end

        context "when workspace is not in desired_state terminated" do
          before do
            workspace.desired_state = ::RemoteDevelopment::Workspaces::States::RUNNING
          end

          it 'validates dns_zone matches agent.remote_development_agent_config.dns_zone' do
            expect(workspace).not_to be_valid
            expect(workspace.errors[:dns_zone])
              .to include("for Workspace must match the dns_zone of the associated RemoteDevelopmentAgentConfig")
          end
        end
      end
    end

    context 'when desired_state is Terminated' do
      let(:desired_state) { ::RemoteDevelopment::Workspaces::States::TERMINATED }

      before do
        workspace.desired_state = ::RemoteDevelopment::Workspaces::States::STOPPED
      end

      it 'prevents changes to desired_state' do
        expect(workspace).not_to be_valid
        expect(workspace.errors[:desired_state])
          .to include("is 'Terminated', and cannot be updated. Create a new workspace instead.")
      end
    end

    describe "#workspaces_count_for_current_user_and_agent" do
      let_it_be(:user1) { create(:user) }
      let_it_be(:user2) { create(:user) }
      let_it_be(:user3) { create(:user) }
      let_it_be(:agent1, reload: true) { create(:ee_cluster_agent, :with_remote_development_agent_config) }
      let_it_be(:agent2, reload: true) { create(:ee_cluster_agent, :with_remote_development_agent_config) }
      let_it_be(:workspace1) do
        create(:workspace, user: user1, agent: agent1, desired_state: ::RemoteDevelopment::Workspaces::States::RUNNING)
      end

      let_it_be(:workspace2) do
        create(:workspace, user: user2, agent: agent1,
          desired_state: ::RemoteDevelopment::Workspaces::States::TERMINATED)
      end

      let_it_be(:workspace3) do
        create(:workspace, user: user1, agent: agent1, desired_state: ::RemoteDevelopment::Workspaces::States::STOPPED)
      end

      let_it_be(:workspace4) do
        create(:workspace, user: user2, agent: agent2,
          desired_state: ::RemoteDevelopment::Workspaces::States::TERMINATED)
      end

      let_it_be(:workspace5) do
        create(:workspace, user: user3, agent: agent2, desired_state: ::RemoteDevelopment::Workspaces::States::RUNNING)
      end

      it "returns the correct count for the current user and agent" do
        expect(workspace1.workspaces_count_for_current_user_and_agent).to eq(2)
        expect(workspace2.workspaces_count_for_current_user_and_agent).to eq(0)
        expect(workspace4.workspaces_count_for_current_user_and_agent).to eq(0)
        expect(workspace5.workspaces_count_for_current_user_and_agent).to eq(1)
      end
    end

    describe "#workspaces_count_for_current_agent" do
      let_it_be(:agent1, reload: true) { create(:ee_cluster_agent, :with_remote_development_agent_config) }
      let_it_be(:agent2, reload: true) { create(:ee_cluster_agent, :with_remote_development_agent_config) }
      let_it_be(:workspace1) do
        create(:workspace, agent: agent1, desired_state: ::RemoteDevelopment::Workspaces::States::RUNNING)
      end

      let_it_be(:workspace2) do
        create(:workspace, agent: agent1, desired_state: ::RemoteDevelopment::Workspaces::States::TERMINATED)
      end

      let_it_be(:workspace3) do
        create(:workspace, agent: agent1, desired_state: ::RemoteDevelopment::Workspaces::States::STOPPED)
      end

      let_it_be(:workspace4) do
        create(:workspace, agent: agent2, desired_state: ::RemoteDevelopment::Workspaces::States::TERMINATED)
      end

      let_it_be(:workspace5) do
        create(:workspace, agent: agent2, desired_state: ::RemoteDevelopment::Workspaces::States::RUNNING)
      end

      it "returns the correct count for the current agent" do
        expect(workspace1.workspaces_count_for_current_agent).to eq(2)
        expect(workspace4.workspaces_count_for_current_agent).to eq(1)
        expect(workspace5.workspaces_count_for_current_agent).to eq(1)
      end
    end

    describe "#exceeds_workspaces_per_user_quota?" do
      let(:workspace) { create(:workspace) }

      context "when remote_development_agent_config is nil" do
        it "returns false" do
          workspace.remote_development_agent_config = nil
          expect(workspace.exceeds_workspaces_per_user_quota?).to be nil
        end
      end

      context "when remote_development_agent_config is present" do
        context "when workspaces_per_user_quota is 0" do
          before do
            allow(workspace).to receive(:remote_development_agent_config).and_return(instance_double(
              RemoteDevelopment::RemoteDevelopmentAgentConfig, workspaces_per_user_quota: 0))
          end

          it "returns true" do
            expect(workspace.exceeds_workspaces_per_user_quota?).to be true
          end
        end

        context "when workspaces_per_user_quota is -1" do
          before do
            allow(workspace).to receive(:remote_development_agent_config).and_return(instance_double(
              RemoteDevelopment::RemoteDevelopmentAgentConfig, workspaces_per_user_quota: -1))
          end

          it "returns false" do
            expect(workspace.exceeds_workspaces_per_user_quota?).to be false
          end
        end

        context "when workspaces_per_user_quota is greater than 0" do
          before do
            allow(workspace).to receive(:remote_development_agent_config).and_return(instance_double(
              RemoteDevelopment::RemoteDevelopmentAgentConfig, workspaces_per_user_quota: 2))
          end

          it "returns true if the workspaces count for current user and agent is greater than or equal to the quota" do
            allow(workspace).to receive(:workspaces_count_for_current_user_and_agent).and_return(3)
            expect(workspace.exceeds_workspaces_per_user_quota?).to be true
          end

          it "returns false if the workspaces count for current user and agent is less than the quota" do
            allow(workspace).to receive(:workspaces_count_for_current_user_and_agent).and_return(1)
            expect(workspace.exceeds_workspaces_per_user_quota?).to be false
          end
        end
      end
    end

    describe "#exceeds_workspaces_quota?" do
      let(:workspace) { create(:workspace) }

      context "when remote_development_agent_config is nil" do
        it "returns false" do
          workspace.remote_development_agent_config = nil
          expect(workspace.exceeds_workspaces_quota?).to be nil
        end
      end

      context "when remote_development_agent_config is present" do
        context "when workspaces_quota is 0" do
          before do
            allow(workspace).to receive(:remote_development_agent_config).and_return(instance_double(
              RemoteDevelopment::RemoteDevelopmentAgentConfig, workspaces_quota: 0))
          end

          it "returns true" do
            expect(workspace.exceeds_workspaces_quota?).to be true
          end
        end

        context "when workspaces_quota is -1" do
          before do
            allow(workspace).to receive(:remote_development_agent_config).and_return(instance_double(
              RemoteDevelopment::RemoteDevelopmentAgentConfig, workspaces_quota: -1))
          end

          it "returns false" do
            expect(workspace.exceeds_workspaces_quota?).to be false
          end
        end

        context "when workspaces_quota is greater than 0" do
          before do
            allow(workspace).to receive(:remote_development_agent_config).and_return(instance_double(
              RemoteDevelopment::RemoteDevelopmentAgentConfig, workspaces_quota: 2))
          end

          it "returns true if the workspaces count for the current agent is greater than or equal to the quota" do
            allow(workspace).to receive(:workspaces_count_for_current_agent).and_return(3)
            expect(workspace.exceeds_workspaces_quota?).to be true
          end

          it "returns false if the workspaces count for the current agent is less than the quota" do
            allow(workspace).to receive(:workspaces_count_for_current_agent).and_return(1)
            expect(workspace.exceeds_workspaces_quota?).to be false
          end
        end
      end
    end

    describe '#enforce_quotas' do
      subject(:workspace) do
        build(:workspace,
          user: user,
          agent: agent,
          project: project,
          personal_access_token: personal_access_token, desired_state: desired_state)
      end

      before do
        allow(workspace).to receive(:exceeds_workspaces_per_user_quota?).and_return(false)
        allow(workspace).to receive(:exceeds_workspaces_quota?).and_return(false)
      end

      it 'does not add base errors when quotas are not exceeded' do
        workspace.validate
        expect(workspace.errors[:base]).to be_empty
      end

      it 'adds base error when per user quota exceeded' do
        allow(workspace).to receive(:remote_development_agent_config).and_return(instance_double(
          ::RemoteDevelopment::RemoteDevelopmentAgentConfig, workspaces_per_user_quota: 5))
        allow(workspace).to receive(:workspaces_count_for_current_user_and_agent).and_return(6)
        allow(workspace).to receive(:exceeds_workspaces_per_user_quota?).and_return(true)
        workspace.validate
        message = "You cannot create a workspace because you already have \"6\" \
existing workspaces for the given agent with a per user quota of \"5\" workspaces"
        expect(workspace.errors[:base]).to include(message)
      end

      it 'adds base error when total quota exceeded' do
        allow(workspace).to receive(:remote_development_agent_config).and_return(instance_double(
          ::RemoteDevelopment::RemoteDevelopmentAgentConfig, workspaces_quota: 3))
        allow(workspace).to receive(:workspaces_count_for_current_agent).and_return(3)
        allow(workspace).to receive(:exceeds_workspaces_quota?).and_return(true)
        workspace.validate
        message = "You cannot create a workspace because there are already \"3\" \
existing workspaces for the given agent with a total quota of \"3\" workspaces"
        expect(workspace.errors[:base]).to include(message)
      end
    end
  end
end
