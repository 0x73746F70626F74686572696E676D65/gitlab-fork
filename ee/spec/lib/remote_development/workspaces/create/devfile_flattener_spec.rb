# frozen_string_literal: true

require_relative "../../rd_fast_spec_helper"

RSpec.describe RemoteDevelopment::Workspaces::Create::DevfileFlattener, :rd_fast, feature_category: :remote_development do
  include_context 'with remote development shared fixtures'

  let(:devfile_yaml) { example_devfile }
  let(:devfile) { YAML.safe_load(devfile_yaml) }
  let(:expected_processed_devfile) { YAML.safe_load(example_flattened_devfile) }
  let(:context) { { devfile: devfile } }

  subject(:result) do
    described_class.flatten(context)
  end

  it "merges flattened devfile to passed context" do
    expect(result).to eq(
      Gitlab::Fp::Result.ok(
        {
          devfile: devfile,
          processed_devfile: expected_processed_devfile
        }
      )
    )
  end

  context "when devfile has no components" do
    let(:devfile_yaml) { read_devfile('example.no-components-devfile.yaml') }
    let(:expected_processed_devfile) do
      YAML.safe_load(read_devfile('example.no-components-flattened-devfile.yaml'))
    end

    it "adds an empty components entry" do
      expect(result).to eq(
        Gitlab::Fp::Result.ok(
          {
            devfile: devfile,
            processed_devfile: expected_processed_devfile
          }
        )
      )
    end
  end

  context "when flatten raises a Devfile::CliError" do
    let(:devfile_yaml) { read_devfile('example.invalid-extra-field-devfile.yaml') }

    it "returns the error message from the CLI" do
      expected_error_message =
        "error parsing devfile because of non-compliant data due to invalid devfile schema. errors :\n" \
          "- (root): Additional property random is not allowed\n"
      message = result.unwrap_err
      expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceCreateDevfileFlattenFailed)
      expect(message.content).to eq(details: expected_error_message)
    end
  end
end
