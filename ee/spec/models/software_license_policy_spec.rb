# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SoftwareLicensePolicy, feature_category: :software_composition_analysis do
  let(:software_license_policy) { build(:software_license_policy) }

  subject { software_license_policy }

  describe 'validations' do
    it { is_expected.to include_module(Presentable) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:classification) }

    context 'when not associated with a software_license or custom_software_license' do
      let(:software_license_policy) { build(:software_license_policy, software_license: nil, custom_software_license: nil) }

      it { is_expected.not_to be_valid }
    end

    context 'when associated with a software_license' do
      let(:software_license_policy) { build(:software_license_policy, software_license: build(:software_license), custom_software_license: nil) }

      it { is_expected.to be_valid }

      it { is_expected.to validate_uniqueness_of(:software_license).scoped_to([:project_id, :scan_result_policy_id]).with_message(/has already been taken/) }
    end

    context 'when associated with a custom_software_license' do
      let_it_be(:project) { create(:project) }
      let_it_be(:custom_software_license) { create(:custom_software_license) }
      let_it_be(:software_license_policy) { build(:software_license_policy, project: project, software_license: nil, custom_software_license: custom_software_license) }

      it { is_expected.to be_valid }

      context 'when uniqueness is enforced' do
        let!(:software_license_policy) { create(:software_license_policy, project: project, software_license: nil, custom_software_license: custom_software_license) }

        context 'with same custom_license, project, and scan_result_policy' do
          let(:message) { 'Custom software license has already been taken' }

          it 'disallows on create' do
            another_software_license_policy = build(:software_license_policy, project: project, software_license: nil, custom_software_license: custom_software_license)

            expect(another_software_license_policy).not_to be_valid
            expect(another_software_license_policy.errors.full_messages).to include(message)
          end
        end
      end
    end
  end

  describe ".with_license_by_name" do
    subject { described_class }

    let!(:mit_policy) { create(:software_license_policy, software_license: mit) }
    let!(:mit) { create(:software_license, :mit) }
    let!(:apache_policy) { create(:software_license_policy, software_license: apache) }
    let!(:apache) { create(:software_license, :apache_2_0) }

    it 'finds a license by an exact match' do
      expect(subject.with_license_by_name(mit.name)).to match_array([mit_policy])
    end

    it 'finds a license by a case insensitive match' do
      expect(subject.with_license_by_name('mIt')).to match_array([mit_policy])
    end

    it 'finds multiple licenses' do
      expect(subject.with_license_by_name([mit.name, apache.name])).to match_array([mit_policy, apache_policy])
    end
  end

  describe ".by_spdx" do
    let_it_be(:mit) { create(:software_license, :mit) }
    let_it_be(:mit_policy) { create(:software_license_policy, software_license: mit) }
    let_it_be(:apache) { create(:software_license, :apache_2_0) }
    let_it_be(:apache_policy) { create(:software_license_policy, software_license: apache) }

    it { expect(described_class.by_spdx(mit.spdx_identifier)).to match_array([mit_policy]) }
    it { expect(described_class.by_spdx([mit.spdx_identifier, apache.spdx_identifier])).to match_array([mit_policy, apache_policy]) }
    it { expect(described_class.by_spdx(SecureRandom.uuid)).to be_empty }
  end

  describe '.exclusion_allowed' do
    let_it_be(:mit) { create(:software_license, :mit) }
    let_it_be(:scan_result_policy_read_with_inclusion) { create(:scan_result_policy_read, match_on_inclusion_license: true) }
    let_it_be(:scan_result_policy_read_without_inclusion) { create(:scan_result_policy_read, match_on_inclusion_license: false) }
    let!(:mit_policy) { create(:software_license_policy, software_license: mit) }
    let!(:mit_policy_with_inclusion) { create(:software_license_policy, software_license: mit, scan_result_policy_read: scan_result_policy_read_with_inclusion) }
    let!(:mit_policy_without_inclusion) { create(:software_license_policy, software_license: mit, scan_result_policy_read: scan_result_policy_read_without_inclusion) }

    it { expect(described_class.exclusion_allowed).to eq([mit_policy_without_inclusion]) }
  end

  describe "#name" do
    context 'when the feature flag custom_software_license is disabled' do
      before do
        stub_feature_flags(custom_software_license: false)
      end

      specify { expect(subject.name).to eql(subject.software_license.name) }
    end

    context 'when the feature flag custom_software_license is enabled' do
      before do
        stub_feature_flags(custom_software_license: true)
      end

      context 'when associated with a custom_software_license' do
        let_it_be(:project) { create(:project) }
        let_it_be(:custom_software_license) { create(:custom_software_license) }
        let_it_be(:software_license_policy) { build(:software_license_policy, project: project, software_license: nil, custom_software_license: custom_software_license) }

        specify { expect(subject.name).to eql(subject.custom_software_license.name) }
      end
    end
  end

  describe "#approval_status" do
    where(:classification, :approval_status) do
      [
        %w[allowed allowed],
        %w[denied denied]
      ]
    end

    with_them do
      subject { build(:software_license_policy, classification: classification) }

      it { expect(subject.approval_status).to eql(approval_status) }
    end
  end
end
