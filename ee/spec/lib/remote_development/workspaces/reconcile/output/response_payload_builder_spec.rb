# frozen_string_literal: true

require_relative '../../../rd_fast_spec_helper'

RSpec.describe RemoteDevelopment::Workspaces::Reconcile::Output::ResponsePayloadBuilder, :rd_fast, feature_category: :remote_development do
  include_context 'with remote development shared fixtures'

  let(:logger) { instance_double(Logger) }
  let(:desired_state) { RemoteDevelopment::Workspaces::States::RUNNING }
  let(:actual_state) { RemoteDevelopment::Workspaces::States::STOPPED }
  let(:processed_devfile) { example_processed_devfile }
  let(:force_include_all_resources) { false }
  let(:current_config_version) { RemoteDevelopment::Workspaces::ConfigVersion::VERSION_3 }
  let(:previous_config_version) { RemoteDevelopment::Workspaces::ConfigVersion::VERSION_2 }
  let(:workspace) do
    instance_double(
      "RemoteDevelopment::Workspace",
      id: 1,
      name: "workspace",
      namespace: "namespace",
      deployment_resource_version: "1",
      desired_state: desired_state,
      actual_state: actual_state,
      processed_devfile: processed_devfile,
      config_version: config_version,
      force_include_all_resources: force_include_all_resources
    )
  end

  let(:settings) do
    {
      full_reconciliation_interval_seconds: 3600,
      partial_reconciliation_interval_seconds: 10
    }
  end

  let(:context) do
    {
      update_type: update_type,
      workspaces_to_be_returned: [workspace],
      settings: settings,
      logger: logger
    }
  end

  # NOTE: We are setting `expected_include_all_resources` into our fake `generated_config_to_apply` which is mocked to
  #       be returned from DesiredConfigGenerator. This allows us to perform assertions on the expected passed/returned
  #       value of `include_all_resources` using simple `let` statements, and avoid having to write complex mocks.
  let(:generated_config_to_apply) do
    [
      {
        include_all_resources: expected_include_all_resources,
        some_other_key: 1
      }
    ]
  end

  let(:returned_workspace_rails_infos) do
    [
      {
        name: workspace.name,
        namespace: workspace.namespace,
        deployment_resource_version: workspace.deployment_resource_version,
        desired_state: desired_state,
        actual_state: actual_state,
        config_to_apply:
          generated_config_to_apply&.map do |resource|
            YAML.dump(resource.deep_stringify_keys)
          end&.join
      }
    ]
  end

  let(:expected_returned_value) do
    context.merge(
      response_payload: {
        workspace_rails_infos: returned_workspace_rails_infos,
        settings: settings
      },
      observability_for_rails_infos: {
        workspace.name => {
          config_to_apply_resources_included: expected_workspace_resources_included_type
        }
      }
    )
  end

  let(:expected_workspace_resources_included_type) do
    described_class::ALL_RESOURCES_INCLUDED
  end

  subject(:returned_value) do
    described_class.build(context)
  end

  before do
    allow(workspace)
      .to receive(:desired_state_updated_more_recently_than_last_response_to_agent?)
            .and_return(desired_state_updated_more_recently_than_last_response_to_agent)
  end

  context "when workspace.config_version is current version" do
    let(:config_version) { current_config_version }

    before do
      allow(RemoteDevelopment::Workspaces::Reconcile::Output::DesiredConfigGenerator)
        .to(receive(:generate_desired_config))
        .with(hash_including(include_all_resources: expected_include_all_resources)) { generated_config_to_apply }
    end

    context "when update_type is FULL" do
      let(:desired_state_updated_more_recently_than_last_response_to_agent) { false }
      let(:update_type) { RemoteDevelopment::Workspaces::Reconcile::UpdateTypes::FULL }
      let(:expected_include_all_resources) { true }

      it "includes config_to_apply with all resources included" do
        expect(returned_value).to eq(expected_returned_value)
      end
    end

    context "when update_type is PARTIAL" do
      let(:update_type) { RemoteDevelopment::Workspaces::Reconcile::UpdateTypes::PARTIAL }

      context 'when force_include_all_resources is true' do
        let(:force_include_all_resources) { true }
        let(:expected_include_all_resources) { true }

        context "when workspace.desired_state_updated_more_recently_than_last_response_to_agent == true" do
          let(:desired_state_updated_more_recently_than_last_response_to_agent) { true }

          it "includes config_to_apply with all resources included" do
            expect(returned_value).to eq(expected_returned_value)
          end
        end

        context "when workspace.desired_state_updated_more_recently_than_last_response_to_agent == false" do
          let(:desired_state_updated_more_recently_than_last_response_to_agent) { false }

          it "includes config_to_apply with all resources included" do
            expect(returned_value).to eq(expected_returned_value)
          end
        end
      end

      context 'when force_include_all_resources is false' do
        let(:force_include_all_resources) { false }
        let(:expected_include_all_resources) { false }

        context "when workspace.desired_state_updated_more_recently_than_last_response_to_agent == true" do
          let(:desired_state_updated_more_recently_than_last_response_to_agent) { true }
          let(:expected_workspace_resources_included_type) do
            described_class::PARTIAL_RESOURCES_INCLUDED
          end

          it "includes config_to_apply without all resources included" do
            expect(returned_value).to eq(expected_returned_value)
          end
        end

        context "when workspace.desired_state_updated_more_recently_than_last_response_to_agent == false" do
          let(:desired_state_updated_more_recently_than_last_response_to_agent) { false }
          let(:generated_config_to_apply) { nil }
          let(:expected_workspace_resources_included_type) do
            described_class::NO_RESOURCES_INCLUDED
          end

          it "does not includes config_to_apply and returns it as nil" do
            expect(returned_value).to eq(expected_returned_value)
          end
        end
      end
    end
  end

  context "when workspace.config_version is previous version" do
    let(:config_version) { previous_config_version }
    let(:update_type) { RemoteDevelopment::Workspaces::Reconcile::UpdateTypes::FULL }
    let(:desired_state_updated_more_recently_than_last_response_to_agent) { false }
    let(:expected_include_all_resources) { true }

    it "includes config_to_apply with all resources included" do
      allow(RemoteDevelopment::Workspaces::Reconcile::Output::DesiredConfigGeneratorV2)
        .to(receive(:generate_desired_config))
        .with(hash_including(include_all_resources: expected_include_all_resources)) { generated_config_to_apply }

      expect(returned_value).to eq(expected_returned_value)
    end
  end
end
