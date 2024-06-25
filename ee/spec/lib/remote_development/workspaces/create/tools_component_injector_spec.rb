# frozen_string_literal: true

require_relative '../../rd_fast_spec_helper'

RSpec.describe RemoteDevelopment::Workspaces::Create::ToolsComponentInjector, :rd_fast, feature_category: :remote_development do
  include_context 'with remote development shared fixtures'

  let(:input_processed_devfile_name) { 'example.flattened-devfile.yaml' }
  let(:input_processed_devfile) { YAML.safe_load(read_devfile(input_processed_devfile_name)).to_h }
  let(:expected_processed_devfile_name) { 'example.tools-injected-devfile.yaml' }
  let(:expected_processed_devfile) { YAML.safe_load(read_devfile(expected_processed_devfile_name)).to_h }
  let(:tools_injector_image_from_settings) do
    "registry.gitlab.com/gitlab-org/remote-development/gitlab-workspaces-tools:1.0.0"
  end

  let(:settings) do
    {
      tools_injector_image: tools_injector_image_from_settings
    }
  end

  let(:context) do
    {
      processed_devfile: input_processed_devfile,
      volume_mounts: {
        data_volume: {
          path: "/projects"
        }
      },
      settings: settings
    }
  end

  subject(:returned_value) do
    described_class.inject(context)
  end

  before do
    allow(described_class)
      .to receive(:allow_extensions_marketplace_in_workspace_feature_enabled?).and_return(true)
  end

  it 'injects the tools injector component' do
    expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
  end

  context 'when image is overridden in settings' do
    let(:tools_injector_image_from_settings) { 'my/awesome/image:42' }

    it 'uses image override' do
      image_from_processed_devfile = returned_value[:processed_devfile]["components"][2]["container"]["image"]
      expect(image_from_processed_devfile).to eq(tools_injector_image_from_settings)
    end
  end

  context "when allow_extensions_marketplace_in_workspace is disabled" do
    let(:expected_processed_devfile_name) { 'example.tools-injected-marketplace-disabled-devfile.yaml' }

    before do
      allow(described_class)
        .to receive(:allow_extensions_marketplace_in_workspace_feature_enabled?).and_return(false)
    end

    it 'injects the tools injector component' do
      expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
    end
  end
end
