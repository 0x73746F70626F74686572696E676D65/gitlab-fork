# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ml::Candidate, factory_default: :keep do
  let_it_be(:candidate) { create(:ml_candidates, :with_metrics_and_params) }

  let(:project) { candidate.experiment.project }

  describe 'associations' do
    it { is_expected.to belong_to(:experiment) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:params) }
    it { is_expected.to have_many(:metrics) }
    it { is_expected.to have_many(:metadata) }
  end

  describe 'default values' do
    it { expect(described_class.new.iid).to be_present }
  end

  describe '.artifact_root' do
    subject { candidate.artifact_root }

    it { is_expected.to eq("/ml_candidate_#{candidate.iid}/-/") }
  end

  describe '.package_name' do
    subject { candidate.package_name }

    it { is_expected.to eq("ml_candidate_#{candidate.iid}") }
  end

  describe '.package_version' do
    subject { candidate.package_version }

    it { is_expected.to eq('-') }
  end

  describe '.artifact' do
    subject { candidate.artifact }

    context 'when has logged artifacts' do
      let(:package) do
        create(:generic_package, name: candidate.package_name, version: candidate.package_version, project: project)
      end

      it 'returns the package' do
        package

        is_expected.to eq(package)
      end
    end

    context 'when does not have logged artifacts' do
      let(:tested_candidate) { create(:ml_candidates, :with_metrics_and_params) }

      it { is_expected.to be_nil }
    end
  end

  describe '#by_project_id_and_iid' do
    let(:project_id) { candidate.experiment.project_id }
    let(:iid) { candidate.iid }

    subject { described_class.with_project_id_and_iid(project_id, iid) }

    context 'when iid exists', 'and belongs to project' do
      it { is_expected.to eq(candidate) }
    end

    context 'when iid exists', 'and does not belong to project' do
      let(:project_id) { non_existing_record_id }

      it { is_expected.to be_nil }
    end

    context 'when iid does not exist' do
      let(:iid) { 'a' }

      it { is_expected.to be_nil }
    end
  end

  describe "#latest_metrics" do
    let_it_be(:candidate2) { create(:ml_candidates, experiment: candidate.experiment) }
    let!(:metric1) { create(:ml_candidate_metrics, candidate: candidate2) }
    let!(:metric2) { create(:ml_candidate_metrics, candidate: candidate2 ) }
    let!(:metric3) { create(:ml_candidate_metrics, name: metric1.name, candidate: candidate2) }

    subject { candidate2.latest_metrics }

    it 'fetches only the last metric for the name' do
      expect(subject).to match_array([metric2, metric3] )
    end
  end

  describe "#including_metrics_and_params" do
    subject { described_class.including_metrics_and_params.find_by(id: candidate.id) }

    it 'loads latest metrics and params', :aggregate_failures do
      expect(subject.association_cached?(:latest_metrics)).to be(true)
      expect(subject.association_cached?(:params)).to be(true)
    end
  end
end
