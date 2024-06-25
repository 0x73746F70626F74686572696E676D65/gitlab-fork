# frozen_string_literal: true

require 'spec_helper'

# NOTE: This spec cannot use let_it_be because, because that doesn't work when using the `custom_repo` trait of
#       the project factory and subsequently modifying it, because it's a real on-disk repo at `tmp/tests/gitlab-test/`,
#       and any changes made to it are not reverted by let it be (even with reload). This means we also cannot use
#       these `let` declarations in a `before` context, so any mocking of them must occur in the examples themselves.

RSpec.describe ::RemoteDevelopment::Workspaces::Create::Main, :freeze_time, feature_category: :remote_development do
  include_context 'with remote development shared fixtures'

  let(:user) { create(:user) }
  let(:group) { create(:group, name: 'test-group', developers: user) }
  let(:current_user) { user }
  let(:random_string) { 'abcdef' }
  let(:devfile_ref) { 'master' }
  let(:devfile_path) { '.devfile.yaml' }
  let(:devfile_fixture_name) { 'example.devfile.yaml' }
  let(:devfile_yaml) { read_devfile(devfile_fixture_name) }
  let(:processed_devfile) { YAML.safe_load(example_processed_devfile).to_h }
  let(:editor) { 'webide' }
  let(:workspace_root) { '/projects' }
  let(:variables) do
    [
      { key: 'VAR1', value: 'value 1', type: 'ENVIRONMENT' },
      { key: 'VAR2', value: 'value 2', type: 'ENVIRONMENT' }
    ]
  end

  let(:project) do
    files = { devfile_path => devfile_yaml }
    create(:project, :in_group, :custom_repo, path: 'test-project', files: files, namespace: group)
  end

  let(:agent) do
    create(:ee_cluster_agent, :with_remote_development_agent_config, project: project, created_by_user: user)
  end

  let(:params) do
    {
      agent: agent,
      user: user,
      project: project,
      editor: editor,
      max_hours_before_termination: 24,
      desired_state: RemoteDevelopment::Workspaces::States::RUNNING,
      devfile_ref: devfile_ref,
      devfile_path: devfile_path,
      variables: variables
    }
  end

  let(:tools_injector_image_from_settings) do
    "registry.gitlab.com/gitlab-org/remote-development/gitlab-workspaces-tools:1.0.0"
  end

  let(:settings) do
    {
      project_cloner_image: 'alpine/git:2.36.3',
      tools_injector_image: tools_injector_image_from_settings,
      vscode_extensions_gallery: {
        service_url: "https://open-vsx.org/vscode/gallery",
        item_url: "https://open-vsx.org/vscode/item",
        resource_url_template: "https://open-vsx.org/api/{publisher}/{name}/{version}/file/{path}"
      }
    }
  end

  let(:context) { { current_user: current_user, params: params, settings: settings } }

  subject(:response) do
    described_class.main(context)
  end

  context 'when params are valid' do
    before do
      allow(project.repository).to receive_message_chain(:blob_at_branch, :data) { devfile_yaml }
    end

    context 'when devfile is valid' do
      before do
        allow(SecureRandom).to receive(:alphanumeric) { random_string }
      end

      it 'creates a new workspace and returns success', :aggregate_failures do
        # NOTE: This example is structured and ordered to give useful and informative error messages in case of failures
        expect { response }.to change { RemoteDevelopment::Workspace.count }.by(1)

        expect(response.fetch(:status)).to eq(:success)
        expect(response[:message]).to be_nil
        expect(response[:payload]).not_to be_nil
        expect(response[:payload][:workspace]).not_to be_nil

        workspace = response.fetch(:payload).fetch(:workspace)
        expect(workspace.user).to eq(user)
        expect(workspace.agent).to eq(agent)
        expect(workspace.desired_state).to eq(RemoteDevelopment::Workspaces::States::RUNNING)
        # noinspection RubyResolve
        expect(workspace.desired_state_updated_at).to eq(Time.current)
        expect(workspace.actual_state).to eq(RemoteDevelopment::Workspaces::States::CREATION_REQUESTED)
        expect(workspace.name).to eq("workspace-#{agent.id}-#{user.id}-#{random_string}")
        expect(workspace.namespace).to eq("gl-rd-ns-#{agent.id}-#{user.id}-#{random_string}")
        expect(workspace.editor).to eq('webide')
        expect(workspace.url).to eq(URI::HTTPS.build({
          host: "60001-#{workspace.name}.#{workspace.agent.remote_development_agent_config.dns_zone}",
          query: {
            folder: "#{workspace_root}/#{project.path}"
          }.to_query
        }).to_s)
        # noinspection RubyResolve
        expect(workspace.devfile).to eq(devfile_yaml)

        actual_processed_devfile = YAML.safe_load(workspace.processed_devfile).to_h
        expect(actual_processed_devfile).to eq(processed_devfile)

        variables.each do |variable|
          expect(
            RemoteDevelopment::WorkspaceVariable.where(
              workspace: workspace,
              key: variable[:key],
              variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES_FOR_GRAPHQL[variable[:type]]
            ).first&.value
          ).to eq(variable[:value])
        end
      end
    end

    context 'when devfile is not valid', :aggregate_failures do
      let(:devfile_fixture_name) { 'example.invalid-components-entry-missing-devfile.yaml' }

      it 'does not create the workspace and returns error' do
        expect { response }.not_to change { RemoteDevelopment::Workspace.count }

        expect(response).to eq({
          status: :error,
          message: "Workspace create post flatten devfile validation failed: No components present in devfile",
          reason: :bad_request
        })
      end
    end
  end

  context 'when params are invalid' do
    context 'when devfile is not found' do
      let(:devfile_path) { 'not-found.yaml' }

      before do
        allow(project.repository).to receive(:blob_at_branch).and_return(nil)
      end

      it 'does not create the workspace and returns error', :aggregate_failures do
        expect { response }.not_to change { RemoteDevelopment::Workspace.count }

        expect(response).to eq({
          status: :error,
          message:
            "Workspace create devfile load failed: Devfile path '#{devfile_path}' at ref '#{devfile_ref}' " \
              "does not exist in project repository", # rubocop:disable Layout/LineEndStringConcatenationIndentation -- RubyMine formatting conflict. See https://gitlab.com/gitlab-org/gitlab/-/issues/442626
          reason: :bad_request
        })
      end
    end

    context 'when agent has no associated config' do
      let(:agent) { create(:cluster_agent, name: "007") }

      it 'does not create the workspace and returns error' do
        # sanity check on fixture
        expect(agent.remote_development_agent_config).to be_nil

        expect { response }.not_to change { RemoteDevelopment::Workspace.count }

        expect(response).to eq({
          status: :error,
          message: "Workspace create params validation failed: No RemoteDevelopmentAgentConfig found for agent '007'",
          reason: :bad_request
        })
      end
    end
  end

  context "when allow_extensions_marketplace_in_workspace feature flag is disabled" do
    let(:tools_injector_image_from_settings) { 'my/awesome/image:42' }

    before do
      stub_feature_flags(allow_extensions_marketplace_in_workspace: false)
    end

    it 'uses image override' do
      workspace = response.fetch(:payload).fetch(:workspace)
      processed_devfile = YAML.safe_load(workspace.processed_devfile).to_h
      image_from_processed_devfile = processed_devfile["components"]
                                       &.find { |component| component['name'] == 'gl-tools-injector' }
                                       &.dig('container', 'image')
      expect(image_from_processed_devfile).to eq(tools_injector_image_from_settings)
    end
  end
end
