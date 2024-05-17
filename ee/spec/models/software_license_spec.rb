# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SoftwareLicense, feature_category: :security_policy_management do
  subject { build(:software_license) }

  describe 'validations' do
    it { is_expected.to include_module(Presentable) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:spdx_identifier).is_at_most(255) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end

  describe '.unsafe_create_policy_for!' do
    subject { described_class.unsafe_create_policy_for!(project: project, name: mit_license.name, classification: :allowed) }

    let_it_be(:project) { create(:project) }
    let_it_be(:mit_license) { create(:software_license, :mit) }

    it 'calls find_or_create_by!' do
      expect(described_class).to receive(:find_or_create_by!).with(name: mit_license.name).and_call_original

      subject
    end
  end

  describe 'scopes' do
    subject { described_class }

    let_it_be(:mit) { create(:software_license, :mit, spdx_identifier: 'MIT') }
    let_it_be(:apache_2) { create(:software_license, :apache_2_0, spdx_identifier: nil) }

    describe '.by_spdx' do
      it { expect(subject.by_spdx(mit.spdx_identifier)).to contain_exactly(mit) }
    end

    describe '.spdx' do
      it { expect(subject.spdx).to contain_exactly(mit) }
    end

    describe '.by_spdx' do
      it { expect(subject.by_spdx(mit.spdx_identifier)).to contain_exactly(mit) }
    end

    describe '.spdx' do
      it { expect(subject.spdx).to contain_exactly(mit) }
    end

    describe '.by_name' do
      it { expect(subject.by_name(mit.name)).to contain_exactly(mit) }
    end

    describe '.unknown' do
      it { expect(subject.unknown).to contain_exactly(apache_2) }
    end

    describe '.grouped_by_name' do
      it { expect(subject.grouped_by_name.count).to eql(mit.name => 1, apache_2.name => 1) }
    end

    describe '.ordered' do
      it { expect(subject.ordered.pluck(:name)).to eql([apache_2.name, mit.name]) }
    end
  end

  describe "#canonical_id" do
    context "when an SPDX identifier is available" do
      it { expect(build(:software_license, spdx_identifier: 'MIT').canonical_id).to eq('MIT') }
    end

    context "when an SPDX identifier is not available" do
      it { expect(build(:software_license, name: 'MIT License', spdx_identifier: nil).canonical_id).to eq('mit license') }
    end
  end

  describe '.unclassified_licenses_for' do
    subject { described_class.unclassified_licenses_for(project) }

    let_it_be(:mit_license) { create(:software_license, :mit) }
    let_it_be(:apache_license) { create(:software_license, :apache_2_0) }
    let_it_be(:nonstandard_license) { create(:software_license, :user_entered) }
    let_it_be(:project) { create(:project) }

    context 'when a project has not classified licenses' do
      it 'returns each license in the SPDX catalogue ordered by name' do
        expect(subject.to_a).to eql([apache_license, mit_license])
      end
    end

    context 'when some of the licenses are classified' do
      let_it_be(:mit_policy) { create(:software_license_policy, project: project, software_license: mit_license) }

      it 'returns each license in the SPDX catalogue that has not been classified' do
        expect(subject).to contain_exactly(apache_license)
      end
    end
  end

  describe '.all_license_names' do
    subject { described_class.all_license_names }

    let_it_be(:mit_license) { create(:software_license, :mit) }
    let_it_be(:apache_license) { create(:software_license, :apache_2_0) }
    let_it_be(:nonstandard_license) { create(:software_license, :user_entered) }

    it 'returns ordered list of license names from the SPDX catalogue' do
      expect(subject.to_a).to eql([apache_license.name, mit_license.name])
    end

    it 'caches the license names' do
      expect(Rails.cache).to receive(:fetch).with(SoftwareLicense::ALL_LICENSE_NAMES_CACHE_KEY, expires_in: 7.days)

      subject
    end
  end
end
