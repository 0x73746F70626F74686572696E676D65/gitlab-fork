# frozen_string_literal: true

RSpec.describe QA::Tools::Ci::ExportCodePathsMapping do
  include QA::Support::Helpers::StubEnv

  let(:glob) { "test_code_paths/*.json" }
  let(:file_paths) { ["/test_code/test_code_path_mappings.json"] }
  let(:logger) { instance_double("Logger", info: true, warn: true, debug: true) }
  let(:gcs_client_options) { { force: true, content_type: 'application/json' } }
  let(:gcs_client) { double("Fog::Storage::GoogleJSON::Real", put_object: nil) } # rubocop:disable RSpec/VerifiedDoubles -- Class has `put_object` method but is not getting verified
  let(:gcs_project) { 'gitlab-qa-resources' }
  let(:gcs_bucket_name) { 'code-path-mappings' }
  let(:gcs_credentials) { 'code-path-mappings-gcs-credentials' }
  let(:mapping_json) { code_path_mappings_data.to_json }
  let(:code_path_mappings_data) do
    {
      "path_to_spec:rb": ['lib/model.rb']
    }
  end

  let(:pretty_generated_mapping_json) do
    JSON.pretty_generate(code_path_mappings_data)
  end

  before do
    allow(Fog::Storage::Google).to receive(:new)
                                     .with(google_project: gcs_project,
                                       google_json_key_string: gcs_credentials)
                                     .and_return(gcs_client)
    allow(Gitlab::QA::TestLogger).to receive(:logger) { logger }
    allow(Dir).to receive(:glob).with(glob) { file_paths }
    allow(::File).to receive(:read).with(anything).and_return(code_path_mappings_data.to_json)
    stub_env('QA_CODE_PATH_MAPPINGS_GCS_CREDENTIALS', gcs_credentials)
    stub_env('QA_RUN_TYPE', 'package-and-test')
  end

  context "with mapping files present" do
    it "exports mapping json to GCS and writes it as job artifact", :aggregate_failures do
      expect(logger).to receive(:info).with("Number of mapping files found: #{file_paths.size}")
      expect(::File).to receive(:write).with(String, mapping_json).once
      expect(gcs_client).to receive(:put_object).with(gcs_bucket_name,
        String, pretty_generated_mapping_json)
      described_class.export(glob)
    end
  end

  context "with no mapping files present" do
    let(:file_paths) { [] }

    it "exits without any exception raised but logs the error", :aggregate_failures do
      expect(logger).to receive(:warn).with(/No files matched pattern/).once
      expect(::File).not_to receive(:write)
      described_class.export(glob)
    end
  end
end
