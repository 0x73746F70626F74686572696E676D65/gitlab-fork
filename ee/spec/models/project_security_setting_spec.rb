# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectSecuritySetting, feature_category: :software_composition_analysis do
  using RSpec::Parameterized::TableSyntax

  describe 'associations' do
    subject { create(:project).security_setting }

    it { is_expected.to belong_to(:project) }
  end

  describe '#set_continuous_vulnerability_scans' do
    where(:value_before, :enabled, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      let(:setting) { create(:project_security_setting, continuous_vulnerability_scans_enabled: value_before) }

      it 'updates the attribute and returns the new value' do
        expect(setting.set_continuous_vulnerability_scans!(enabled: enabled)).to eq(value_after)
        expect(setting.reload.continuous_vulnerability_scans_enabled).to eq(value_after)
      end
    end
  end

  describe '#set_container_scanning_for_registry' do
    where(:value_before, :enabled, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      let(:setting) { create(:project_security_setting, container_scanning_for_registry_enabled: value_before) }

      it 'updates the attribute and returns the new value' do
        expect(setting.set_container_scanning_for_registry!(enabled: enabled)).to eq(value_after)
        expect(setting.reload.container_scanning_for_registry_enabled).to eq(value_after)
      end
    end
  end

  describe '#set_pre_receive_secret_detection' do
    where(:value_before, :enabled, :value_after) do
      true  | false | false
      true  | true  | true
      false | true  | true
      false | false | false
    end

    with_them do
      let(:setting) { create(:project_security_setting, pre_receive_secret_detection_enabled: value_before) }

      it 'updates the attribute and returns the new value' do
        expect(setting.set_pre_receive_secret_detection!(enabled: enabled)).to eq(value_after)
        expect(setting.reload.pre_receive_secret_detection_enabled).to eq(value_after)
      end
    end
  end
end
