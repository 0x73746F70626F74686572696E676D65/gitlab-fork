# frozen_string_literal: true

require_relative '../../../rd_fast_spec_helper'

RSpec.describe RemoteDevelopment::Workspaces::Reconcile::Input::ParamsToInfosConverter, :rd_fast, feature_category: :remote_development do
  let(:workspace_agent_info_hashes_from_params) do
    [
      {
        name: "workspace1"
      },
      {
        name: "workspace2"
      }
    ]
  end

  let(:expected_agent_info_1) do
    instance_double("RemoteDevelopment::Workspaces::Reconcile::Input::AgentInfo", name: "workspace1")
  end

  let(:expected_agent_info_2) do
    instance_double("RemoteDevelopment::Workspaces::Reconcile::Input::AgentInfo", name: "workspace2")
  end

  let(:context) { { workspace_agent_info_hashes_from_params: workspace_agent_info_hashes_from_params } }

  subject(:returned_value) do
    described_class.convert(context)
  end

  before do
    allow(RemoteDevelopment::Workspaces::Reconcile::Input::Factory)
      .to receive(:build)
            .with(agent_info_hash_from_params: workspace_agent_info_hashes_from_params[0]) { expected_agent_info_1 }
    allow(RemoteDevelopment::Workspaces::Reconcile::Input::Factory)
      .to receive(:build)
            .with(agent_info_hash_from_params: workspace_agent_info_hashes_from_params[1]) { expected_agent_info_2 }
  end

  it "converts array of workspace agent info hashes from params into array of AgentInfo value objects" do
    expect(returned_value).to eq(
      context.merge(
        workspace_agent_infos_by_name: {
          workspace1: expected_agent_info_1,
          workspace2: expected_agent_info_2
        }
      )
    )
  end
end
