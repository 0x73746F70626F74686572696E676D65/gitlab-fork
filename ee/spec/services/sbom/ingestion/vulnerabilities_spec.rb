# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::Vulnerabilities, feature_category: :dependency_management do
  let_it_be(:vulnerability) { create(:vulnerability) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: vulnerability.project) }

  subject(:vulnerabilities) { described_class.new(pipeline).vulnerabilities }

  describe '#fetch' do
    using RSpec::Parameterized::TableSyntax

    where(:feature_flag, :feature_flag_stub) do
      :deprecate_vulnerability_occurrence_pipelines | false
      :deprecate_vulnerability_occurrence_pipelines | true
    end

    with_them do
      let(:finding) do
        create(:vulnerabilities_finding, :with_dependency_scanning_metadata, vulnerability: vulnerability,
          pipeline: pipeline)
      end

      let(:dependency) { finding.location["dependency"] }
      let(:package_name) { dependency['package']['name'] }
      let(:version) { dependency['version'] }
      let(:path) { finding.file }

      subject(:vulnerabilities_fetched) { described_class.new(pipeline).fetch(package_name, version, path) }

      before do
        stub_feature_flags(feature_flag => feature_flag_stub)
      end

      context 'without any vulnerability associated to any depedencies' do
        let(:pipeline) { create(:ci_pipeline) }
        let(:finding) do
          create(:vulnerabilities_finding, :with_dependency_scanning_metadata, vulnerability: vulnerability)
        end

        it { is_expected.to eq({ vulnerability_ids: [], highest_severity: nil }) }
      end

      context 'with an existing dependency' do
        let(:vulnerability_2) { create(:vulnerability, project: pipeline.project) }

        it { is_expected.to eq({ vulnerability_ids: [finding.vulnerability_id], highest_severity: finding.severity }) }

        context 'without dependency attribute' do
          before do
            finding.update!(raw_metadata: {}.to_json)
          end

          it { is_expected.to eq({ vulnerability_ids: [], highest_severity: nil }) }
        end

        context 'with vulnerability findings sharing the same dependency' do
          let!(:finding_2) do
            create(:vulnerabilities_finding,
              :with_dependency_scanning_metadata,
              vulnerability: vulnerability_2,
              severity: severity,
              pipeline: pipeline
            )
          end

          let(:severity) { :critical }

          it do
            is_expected.to eq({
              vulnerability_ids: [finding_2.vulnerability_id, finding.vulnerability_id],
              highest_severity: finding_2.severity
            })
          end

          context 'with vulnerability findings with a lower severity' do
            let(:severity) { :low }

            it do
              is_expected.to eq({
                vulnerability_ids: [finding.vulnerability_id, finding_2.vulnerability_id],
                highest_severity: finding.severity
              })
            end
          end
        end

        context 'with vulnerability findings not sharing the same dependency' do
          before do
            create(:vulnerabilities_finding, :with_container_scanning_metadata, vulnerability: vulnerability_2,
              pipeline: pipeline)
          end

          it do
            is_expected.to eq({ vulnerability_ids: [finding.vulnerability_id], highest_severity: finding.severity })
          end
        end
      end

      context 'with a non-existing dependency' do
        let(:package_name) { 'unknown' }
        let(:version) { '0.0.0' }

        it { is_expected.to eq({ vulnerability_ids: [], highest_severity: nil }) }
      end
    end
  end
end
