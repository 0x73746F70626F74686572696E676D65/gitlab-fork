# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/helpers/remote_development/integration_spec_helpers"

# rubocop:disable RSpec/MultipleMemoizedHelpers -- this is an integration test, it has a lot of fixtures, but only one example, so we don't need let_it_be
RSpec.describe "Full workspaces integration request spec", :freeze_time, feature_category: :remote_development do
  include GraphqlHelpers
  include RemoteDevelopment::IntegrationSpecHelpers
  include_context "with remote development shared fixtures"

  let(:agent_admin_user) { create(:user, name: "Agent Admin User") }
  let(:user) { create(:user, name: "User") }
  let(:current_user) { user }
  let(:common_parent_namespace_name) { "common-parent-group" }
  let(:common_parent_namespace) { create(:group, name: common_parent_namespace_name, owners: agent_admin_user) }
  let(:agent_project_namespace) do
    create(:group, name: "agent-project-group", parent: common_parent_namespace)
  end

  let(:workspace_project_namespace_name) { "workspace-project-group" }
  let(:workspace_project_namespace) do
    create(:group, name: workspace_project_namespace_name, parent: common_parent_namespace)
  end

  let(:workspace_project_name) { "workspace-project" }
  let(:workspace_namespace_path) { "#{common_parent_namespace_name}/#{workspace_project_namespace_name}" }
  let(:random_string) { "abcdef" }
  let(:devfile_ref) { "master" }
  let(:devfile_path) { ".devfile.yaml" }
  let(:devfile_fixture_name) { "example.devfile.yaml" }
  let(:devfile_yaml) do
    read_devfile(
      devfile_fixture_name,
      namespace_path: "#{common_parent_namespace_name}/#{workspace_project_namespace_name}",
      project_name: workspace_project_name
    )
  end

  let(:expected_processed_devfile_yaml) do
    example_processed_devfile(
      namespace_path: "#{common_parent_namespace_name}/#{workspace_project_namespace_name}",
      project_name: workspace_project_name
    )
  end

  let(:expected_processed_devfile) { YAML.safe_load(expected_processed_devfile_yaml).to_h }
  let(:editor) { "webide" }
  let(:workspace_root) { "/projects" }
  let(:variables) do
    [
      { key: "VAR1", value: "value 1", type: "ENVIRONMENT" },
      { key: "VAR2", value: "value 2", type: "ENVIRONMENT" }
    ]
  end

  let(:workspace_project) do
    files = { devfile_path => devfile_yaml }
    create(:project, :in_group, :custom_repo, path: workspace_project_name, files: files,
      namespace: workspace_project_namespace, developers: user)
  end

  let(:agent_project) do
    create(:project, path: "agent-project", developers: user, namespace: agent_project_namespace)
  end

  let(:agent) do
    create(:ee_cluster_agent, :with_remote_development_agent_config, project: agent_project,
      created_by_user: agent_admin_user)
  end

  let(:namespace_create_remote_development_cluster_agent_mapping_create_mutation_args) do
    {
      namespace_id: common_parent_namespace.to_global_id.to_s,
      cluster_agent_id: agent.to_global_id.to_s
    }
  end

  let(:workspace_create_mutation_args) do
    {
      desired_state: RemoteDevelopment::Workspaces::States::RUNNING,
      editor: "webide",
      max_hours_before_termination: 24,
      cluster_agent_id: agent.to_global_id.to_s,
      project_id: workspace_project.to_global_id.to_s,
      devfile_ref: devfile_ref,
      devfile_path: devfile_path,
      variables: variables
    }
  end

  # Agent setup
  let(:jwt_secret) { SecureRandom.random_bytes(Gitlab::Kas::SECRET_LENGTH) }
  let(:agent_token) { create(:cluster_agent_token, agent: agent) }

  before do
    stub_licensed_features(remote_development: true)
    allow(SecureRandom).to receive(:alphanumeric) { random_string }

    allow(Gitlab::Kas).to receive(:secret).and_return(jwt_secret)

    allow(workspace_project.repository).to receive_message_chain(:blob_at_branch, :data) { devfile_yaml }

    # reload projects, so any local debugging performed in the tests has the correct state
    workspace_project.reload
    agent_project.reload
  end

  def do_create_mapping
    do_graphql_mutation_post(
      name: :namespace_create_remote_development_cluster_agent_mapping,
      input: namespace_create_remote_development_cluster_agent_mapping_create_mutation_args,
      user: agent_admin_user
    )
  end

  def do_create_workspace # rubocop:disable Metrics/AbcSize -- We want this to stay a single method
    create_mutation_response = do_graphql_mutation_post(
      name: :workspace_create,
      input: workspace_create_mutation_args,
      user: user
    )

    workspace_gid = create_mutation_response.fetch("workspace").fetch("id")
    workspace_id = GitlabSchema.parse_gid(workspace_gid, expected_type: ::RemoteDevelopment::Workspace).model_id
    workspace = ::RemoteDevelopment::Workspace.find(workspace_id)

    # NOTE: Where possible, avoid explicit assertions here and replace them with assertions on the
    #       response_json data sent in the reconciliation loop "simulate_N_poll" methods.

    expect(workspace.user).to eq(user)
    expect(workspace.agent).to eq(agent)
    # noinspection RubyResolve
    expect(workspace.desired_state_updated_at).to eq(Time.current)
    expect(workspace.name).to eq("workspace-#{agent.id}-#{user.id}-#{random_string}")
    expect(workspace.namespace).to eq("gl-rd-ns-#{agent.id}-#{user.id}-#{random_string}")
    expect(workspace.editor).to eq("webide")
    expect(workspace.url).to eq(URI::HTTPS.build({
      host: "60001-#{workspace.name}.#{workspace.agent.remote_development_agent_config.dns_zone}",
      query: {
        folder: "#{workspace_root}/#{workspace_project.path}"
      }.to_query
    }).to_s)
    # noinspection RubyResolve
    expect(workspace.devfile).to eq(devfile_yaml)
    actual_processed_devfile = YAML.safe_load(workspace.processed_devfile).to_h
    expect(actual_processed_devfile.fetch("components")).to eq(expected_processed_devfile.fetch("components"))
    expect(actual_processed_devfile).to eq(expected_processed_devfile)
    variables.each do |variable|
      expect(
        RemoteDevelopment::WorkspaceVariable.where(
          workspace: workspace,
          key: variable[:key],
          variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES_FOR_GRAPHQL[variable[:type]]
        ).first&.value
      ).to eq(variable[:value])
    end

    workspace
  end

  def do_stop_workspace(workspace)
    workspace_update_mutation_args = {
      id: global_id_of(workspace),
      desired_state: RemoteDevelopment::Workspaces::States::STOPPED
    }

    do_graphql_mutation_post(
      name: :workspace_update,
      input: workspace_update_mutation_args,
      user: user
    )

    # NOTE: Where possible, avoid explicit assertions here and replace them with assertions on the
    #       response_json data sent in the reconciliation loop "simulate_N_poll" methods.

    # noinspection RubyResolve
    expect(workspace.reload.desired_state_updated_at).to eq(Time.current)
  end

  def do_graphql_mutation_post(name:, input:, user:)
    mutation = graphql_mutation(name, input)
    post_graphql_mutation(mutation, current_user: user)
    expect_graphql_errors_to_be_empty
    mutation_response = graphql_mutation_response(name)
    expect(mutation_response.fetch("errors")).to eq([])
    mutation_response
  end

  def simulate_agentk_reconcile_post(workspace_agent_infos:, update_type:, agent_token:)
    # Add `travel(...)` based on full or partial reconciliation interval in response body
    reconciliation_interval =
      ::RemoteDevelopment::Settings.get_single_setting(:partial_reconciliation_interval_seconds).to_i
    travel(reconciliation_interval)

    jwt_token = JWT.encode(
      { "iss" => Gitlab::Kas::JWT_ISSUER, 'aud' => Gitlab::Kas::JWT_AUDIENCE },
      Gitlab::Kas.secret,
      "HS256"
    )
    agent_token_headers = {
      "Authorization" => "Bearer #{agent_token.token}",
      Gitlab::Kas::INTERNAL_API_REQUEST_HEADER => jwt_token
    }

    post_params = {
      update_type: update_type,
      workspace_agent_infos: workspace_agent_infos
    }
    reconcile_url = api("/internal/kubernetes/modules/remote_development/reconcile", personal_access_token: agent_token)
    post reconcile_url, params: post_params, headers: agent_token_headers, as: :json

    expect(response).to have_gitlab_http_status(:created)
    response_json = json_response.deep_symbolize_keys

    reconciliation_interval_from_response =
      response_json.fetch(:settings).fetch(:partial_reconciliation_interval_seconds).to_i
    expect(reconciliation_interval_from_response).to eq(reconciliation_interval)

    response_json
  end

  it "successfully exercises the full lifecycle of a workspace" do
    # CREATE THE MAPPING VIA GRAPHQL API, SO WE HAVE PROPER AUTHORIZATION
    do_create_mapping

    # DO THE INITAL WORKSPACE CREATION VIA GRAPHQL API
    workspace = do_create_workspace

    # SIMULATE FIRST POLL FROM AGENTK TO PICK UP NEW WORKSPACE
    simulate_first_poll(
      workspace: workspace.reload,
      namespace_path: workspace_namespace_path,
      project_name: workspace_project_name
    ) do |workspace_agent_infos:, update_type:|
      simulate_agentk_reconcile_post(
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type,
        agent_token: agent_token
      )
    end

    # noinspection RubyResolve
    expect(workspace.reload.responded_to_agent_at).to eq(Time.current)

    # SIMULATE SECOND POLL FROM AGENTK TO UPDATE WORKSPACE TO RUNNING STATE
    simulate_second_poll(workspace: workspace.reload) do |workspace_agent_infos:, update_type:|
      simulate_agentk_reconcile_post(
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type,
        agent_token: agent_token
      )
    end

    # UPDATE WORKSPACE DESIRED_STATE TO STOPPED VIA GRAPHQL API
    do_stop_workspace(workspace)

    # SIMULATE THIRD POLL FROM AGENTK TO UPDATE WORKSPACE TO STOPPING STATE
    simulate_third_poll(
      workspace: workspace.reload,
      namespace_path: workspace_namespace_path,
      project_name: workspace_project_name
    ) do |workspace_agent_infos:, update_type:|
      simulate_agentk_reconcile_post(
        agent_token: agent_token,
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type
      )
    end

    # SIMULATE FOURTH POLL FROM AGENTK TO UPDATE WORKSPACE TO STOPPED STATE
    simulate_fourth_poll(workspace: workspace.reload) do |workspace_agent_infos:, update_type:|
      simulate_agentk_reconcile_post(
        agent_token: agent_token,
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type
      )
    end

    # SIMULATE FIFTH POLL FROM AGENTK FOR PARTIAL RECONCILE TO SHOW NO RAILS_INFOS ARE SENT
    simulate_fifth_poll do |workspace_agent_infos:, update_type:|
      simulate_agentk_reconcile_post(
        agent_token: agent_token,
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type
      )
    end

    # SIMULATE SIXTH POLL FROM AGENTK FOR FULL RECONCILE TO SHOW ALL WORKSPACES ARE SENT IN RAILS_INFOS
    simulate_sixth_poll(
      workspace: workspace.reload,
      namespace_path: workspace_namespace_path,
      project_name: workspace_project_name
    ) do |workspace_agent_infos:, update_type:|
      simulate_agentk_reconcile_post(
        agent_token: agent_token,
        workspace_agent_infos: workspace_agent_infos,
        update_type: update_type
      )
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
