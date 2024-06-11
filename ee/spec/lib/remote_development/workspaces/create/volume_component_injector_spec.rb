# frozen_string_literal: true

require "spec_helper"

RSpec.describe RemoteDevelopment::Workspaces::Create::VolumeComponentInjector, feature_category: :remote_development do
  include_context 'with remote development shared fixtures'

  let(:input_processed_devfile_name) { 'example.project-cloner-injected-devfile.yaml' }
  let(:input_processed_devfile) { YAML.safe_load(read_devfile(input_processed_devfile_name)).to_h }
  let(:expected_processed_devfile_name) { 'example.processed-devfile.yaml' }
  let(:expected_processed_devfile) { YAML.safe_load(read_devfile(expected_processed_devfile_name)).to_h }
  let(:component_name) { "gl-workspace-data" }
  let(:volume_name) { "gl-workspace-data" }
  let(:context) do
    {
      processed_devfile: input_processed_devfile,
      volume_mounts: {
        data_volume: {
          name: volume_name,
          path: "/projects"
        }
      }
    }
  end

  subject(:returned_value) do
    described_class.inject(context)
  end

  it "injects the workspace volume component" do
    expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
  end
end
