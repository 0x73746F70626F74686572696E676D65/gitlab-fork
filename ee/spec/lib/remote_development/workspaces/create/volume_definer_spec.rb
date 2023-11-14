# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::Workspaces::Create::VolumeDefiner, feature_category: :remote_development do
  let(:value) { { params: 1 } }

  subject(:returned_value) do
    described_class.define(value)
  end

  it "merges volume mount info to passed value" do
    expect(returned_value).to eq(
      {
        params: 1,
        volume_mounts: {
          data_volume: {
            name: "gl-workspace-data",
            path: "/projects"
          }
        }
      }
    )
  end
end
