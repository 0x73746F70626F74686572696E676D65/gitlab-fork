# frozen_string_literal: true

#   What does this test do
#
#   This is an e2e test that sets up the entire workspaces environment from scratch as mentioned in this documentation
#   https://gitlab.com/gitlab-org/remote-development/gitlab-remote-development-docs/-/blob/main/doc/local-development-environment-setup.md
#   This test creates project, devfile, agents and workspaces on the fly
#   The other test ee/browser_ui/3_create/remote_development/with_prerequisite_done/
#   workspace_actions_with_prerequisite_done_spec.rb is used for local testing and requires an existing agent and
#   devfile project
#
#   How to run the test
#
#   1. Run the test against staging environment
#      The full list of env variable and their values to run this test can be found in 1password "Run workspaces tests
#      against staging"
#      bundle exec bin/qa Test::Instance::All https://staging.gitlab.com -- -- qa/specs/features/ee/browser_ui/3_create
#      /remote_development/workspace_actions_spec.rb
#   2. When the test is run locally, it will try to install helm (requires local password) and if unnoticed the script
#      would fail eventually. To overcome this, install helm manually using the installation steps in
#      https://gitlab.com/gitlab-org/gitlab/-/blob/6bb010046a9f8922f827eb035d05e28954352311/qa/qa/service/cluster_provider/gcloud.rb#L129-135
#      then run the test using step 1

module QA
  RSpec.describe 'Create', only: { pipeline: %i[staging staging-canary] }, product_group: :ide do
    describe 'Remote Development' do
      include Runtime::Fixtures

      context 'when prerequisite is done in runtime',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/419248' do
        let!(:cluster) do
          if QA::Runtime::Env.workspaces_cluster_available?
            Service::KubernetesCluster.new(provider_class: Service::ClusterProvider::Gcloud).connect!
          else
            Service::KubernetesCluster.new(provider_class: Service::ClusterProvider::Gcloud).create!
          end
        end

        let(:parent_group) do
          create(:group, path: "parent-group-to-test-remote-development-#{SecureRandom.hex(8)}")
        end

        let(:agent_project) { create(:project, group: parent_group, name: 'agent-project') }
        let(:kubernetes_agent) do
          create(:cluster_agent, name: "remotedev-#{SecureRandom.hex(4)}", project: agent_project)
        end

        let!(:agent_token) { create(:cluster_agent_token, agent: kubernetes_agent) }

        let!(:agent_config_file) do
          agent_config_yaml = ERB.new(read_ee_fixture('remote_development', 'agent-config.yaml.erb')).result(binding)
          create(:commit, project: agent_project, commit_message: 'Add remote dev agent configuration', actions: [
            {
              action: 'create',
              file_path: ".gitlab/agents/#{kubernetes_agent.name}/config.yaml",
              content: agent_config_yaml
            }
          ])
        end

        let(:devfile_project) { create(:project, group: parent_group, name: 'devfile-project') }
        let!(:devfile_file) do
          devfile_yaml = ERB.new(read_ee_fixture('remote_development', 'devfile.yaml.erb')).result(binding)

          create(:commit, project: devfile_project, commit_message: 'Add .devfile.yaml', actions: [
            { action: 'create', file_path: '.devfile.yaml', content: devfile_yaml }
          ])
        end

        before do
          cluster.setup_workspaces_in_cluster unless QA::Runtime::Env.workspaces_cluster_available?
          cluster.install_kubernetes_agent(agent_token.token, kubernetes_agent.name)
          cluster.update_dns_with_load_balancer_ip
          Flow::Login.sign_in
        end

        after do
          if QA::Runtime::Env.workspaces_cluster_available?
            cluster.uninstall_kubernetes_agent(kubernetes_agent.name)
          else
            cluster&.remove!
          end

          agent_token.remove_via_api!
          kubernetes_agent.remove_via_api!
          parent_group.remove_via_api!
        end

        it_behaves_like 'workspaces actions'
      end
    end
  end
end
