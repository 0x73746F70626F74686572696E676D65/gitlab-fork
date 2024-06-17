# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupMergeRequestApprovalSetting, feature_category: :compliance_managment do
  describe 'Associations' do
    it { is_expected.to belong_to :group }
  end

  describe 'Validations' do
    let_it_be(:setting) { create(:group_merge_request_approval_setting) }

    subject(:approval_setting) { setting }

    options = [true, false]
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_inclusion_of(:allow_author_approval).in_array(options) }
    it { is_expected.to validate_inclusion_of(:allow_committer_approval).in_array(options) }
    it { is_expected.to validate_inclusion_of(:allow_overrides_to_approver_list_per_merge_request).in_array(options) }
    it { is_expected.to validate_inclusion_of(:retain_approvals_on_push).in_array(options) }
    it { is_expected.to validate_inclusion_of(:require_password_to_approve).in_array(options) }
    it { is_expected.to validate_inclusion_of(:require_reauthentication_to_approve).in_array(options) }
  end

  describe '.find_or_initialize_by_group' do
    let_it_be(:group) { create(:group) }

    subject(:approval_setting_for_group) { described_class.find_or_initialize_by_group(group) }

    context 'with no existing setting' do
      it { is_expected.to be_a_new_record }
    end

    context 'with existing setting' do
      let_it_be(:setting) { create(:group_merge_request_approval_setting, group: group) }

      it { is_expected.to eq(setting) }
    end
  end

  describe 'require authentication for approval' do
    let(:setting) { build(:group_merge_request_approval_setting) }

    it 'sets require_reauthentication_to_approve along with require_password_to_approve' do
      setting.require_password_to_approve = false

      expect(setting.require_reauthentication_to_approve).to be_falsy
      expect(setting.require_password_to_approve).to be_falsy

      setting.require_password_to_approve = true

      expect(setting.require_reauthentication_to_approve).to be_truthy
      expect(setting.require_password_to_approve).to be_truthy

      setting.save!
      setting.reload

      # persisted the change
      expect(setting.require_reauthentication_to_approve).to be_truthy
      expect(setting.require_password_to_approve).to be_truthy
    end

    it 'sets require_password_to_approve along with require_reauthentication_to_approve' do
      setting.require_reauthentication_to_approve = false

      expect(setting.require_reauthentication_to_approve).to be_falsy
      expect(setting.require_password_to_approve).to be_falsy

      setting.require_reauthentication_to_approve = true

      expect(setting.require_password_to_approve).to be_truthy
      expect(setting.require_reauthentication_to_approve).to be_truthy

      expect(setting).to be_valid
      setting.save!
      setting.reload

      # persisted the change
      expect(setting.require_password_to_approve).to be_truthy
      expect(setting.require_reauthentication_to_approve).to be_truthy
    end
  end
end
