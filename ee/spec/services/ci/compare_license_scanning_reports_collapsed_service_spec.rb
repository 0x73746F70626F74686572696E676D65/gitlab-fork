# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CompareLicenseScanningReportsCollapsedService do
  include ProjectForksHelper

  let_it_be(:project) { create(:project, :repository) }

  let(:service) { described_class.new(project, nil) }

  before do
    stub_licensed_features(license_scanning: true)
  end

  describe '#execute' do
    subject { service.execute(base_pipeline, head_pipeline) }

    context 'when base and head pipelines have test reports' do
      let_it_be(:base_pipeline) { create(:ee_ci_pipeline, :with_license_scanning_report, project: project) }
      let_it_be(:head_pipeline) { create(:ee_ci_pipeline, :with_license_scanning_feature_branch, project: project) }

      it 'exposes report with numbers of licenses by type' do
        expect(subject[:status]).to eq(:parsed)
        expect(subject[:data]['new_licenses']).to eq(1)
        expect(subject[:data]['existing_licenses']).to eq(1)
        expect(subject[:data]['removed_licenses']).to eq(3)
      end
    end

    context 'when head pipeline has corrupted license scanning reports' do
      let_it_be(:base_pipeline) { build(:ee_ci_pipeline, :with_corrupted_license_scanning_report, project: project) }
      let_it_be(:head_pipeline) { build(:ee_ci_pipeline, :with_corrupted_license_scanning_report, project: project) }

      it 'exposes empty report' do
        expect(subject[:status]).to eq(:parsed)
        expect(subject[:data]['new_licenses']).to eq(0)
        expect(subject[:data]['existing_licenses']).to eq(0)
        expect(subject[:data]['removed_licenses']).to eq(0)
      end

      context "when the base pipeline is nil" do
        subject { service.execute(nil, head_pipeline) }

        it 'exposes empty report' do
          expect(subject[:status]).to eq(:parsed)
          expect(subject[:data]['new_licenses']).to eq(0)
          expect(subject[:data]['existing_licenses']).to eq(0)
          expect(subject[:data]['removed_licenses']).to eq(0)
        end
      end
    end
  end

  describe '#serializer_class' do
    subject { service.serializer_class }

    it { is_expected.to be(::LicenseCompliance::CollapsedComparerSerializer) }
  end
end
