# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Parsers::Sbom::Cyclonedx do
  let(:report) { instance_double('Gitlab::Ci::Reports::Sbom::Report') }
  let(:raw_report_data) { report_data.to_json }

  let(:base_report_data) do
    {
      'bomFormat' => 'CycloneDX',
      'specVersion' => '1.4',
      'version' => 1
    }
  end

  subject(:parse!) { described_class.new(raw_report_data, report).parse! }

  context 'when report JSON is invalid' do
    let(:raw_report_data) { '{ ' }

    it 'handles errors and adds them to the report' do
      expect(report).to receive(:add_error).with(a_string_including("Report JSON is invalid:"))

      expect { parse! }.not_to raise_error
    end
  end

  context 'when report uses an unsupported spec version' do
    let(:report_data) { base_report_data.merge({ 'specVersion' => '1.3' }) }

    it 'reports unsupported version as an error' do
      expect(report).to receive(:add_error).with("Unsupported CycloneDX spec version. Must be one of: 1.4")

      parse!
    end
  end

  context 'when cyclonedx report has no components' do
    let(:report_data) { base_report_data }

    it 'skips component processing' do
      expect(report).not_to receive(:add_component)

      parse!
    end
  end

  context 'when report has components' do
    let(:report_data) { base_report_data.merge({ 'components' => components }) }
    let(:components) do
      [
        {
          "name" => "activesupport",
          "version" => "5.1.4",
          "purl" => "pkg:gem/activesupport@5.1.4",
          "type" => "library",
          "bom-ref" => "pkg:gem/activesupport@5.1.4"
        },
        {
          "name" => "byebug",
          "version" => "10.0.0",
          "purl" => "pkg:gem/byebug@10.0.0",
          "type" => "library",
          "bom-ref" => "pkg:gem/byebug@10.0.0"
        },
        {
          "name" => "minimal-component",
          "type" => "library"
        },
        {
          # Should be skipped
          "name" => "unrecognized-type",
          "type" => "unknown"
        }
      ]
    end

    it 'adds each component, ignoring unused attributes' do
      expect(report).to receive(:add_component)
        .with({ "name" => "activesupport", "version" => "5.1.4", "type" => "library" })
      expect(report).to receive(:add_component)
        .with({ "name" => "byebug", "version" => "10.0.0", "type" => "library" })
      expect(report).to receive(:add_component)
        .with({ "name" => "minimal-component", "type" => "library" })

      parse!
    end
  end
end
