# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::PromotionManagementUtils, feature_category: :seat_cost_management do
  include described_class

  let(:current_user) { create(:user) }
  let(:plan_type) { License::ULTIMATE_PLAN }
  let(:license) { create(:license, plan: plan_type) }
  let(:feature_enabled) { true }
  let(:setting_enabled) { true }

  before do
    allow(License).to receive(:current).and_return(license)
    stub_feature_flags(member_promotion_management: feature_enabled)
    stub_application_setting(enable_member_promotion_management: setting_enabled)
  end

  describe '#promotion_management_applicable?' do
    context 'when self-managed' do
      context 'when feature is disabled' do
        let(:feature_enabled) { false }

        it 'returns false' do
          expect(promotion_management_applicable?).to be false
        end
      end

      context 'when setting is disabled' do
        let(:setting_enabled) { false }

        it 'returns false' do
          expect(promotion_management_applicable?).to be false
        end
      end

      context 'when feature and setting is enabled' do
        context 'when guests are excluded' do
          it 'returns true' do
            expect(promotion_management_applicable?).to be true
          end
        end

        context 'when guests are not excluded' do
          let(:plan_type) { License::STARTER_PLAN }

          it 'returns false' do
            expect(promotion_management_applicable?).to be false
          end
        end
      end
    end

    context 'when on saas', :saas do
      it 'returns false' do
        expect(promotion_management_applicable?).to be false
      end
    end
  end

  describe '#promotion_management_required_for_role?', :aggregate_failures do
    let_it_be(:access_level) { ::Gitlab::Access::DEVELOPER }
    let(:billable_role_change_value) { true }

    before do
      allow(self).to receive(:sm_billable_role_change?).and_return(billable_role_change_value)
    end

    subject(:promotion_check) { promotion_management_required_for_role?(new_access_level: access_level) }

    context 'when promotion_management_applicable? returns true' do
      context 'when role change is billable' do
        it { is_expected.to be true }
      end

      context 'when role change is not billable' do
        let(:billable_role_change_value) { false }

        it { is_expected.to be false }
      end
    end

    context 'when promotion_management_applicable? returns false' do
      before do
        allow(self).to receive(:promotion_management_applicable?).and_return(false)
      end

      it { is_expected.to be false }
    end
  end
end
