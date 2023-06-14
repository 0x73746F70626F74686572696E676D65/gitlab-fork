# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchase, feature_category: :subscription_management do
  subject { build(:gitlab_subscription_add_on_purchase) }

  describe 'associations' do
    it { is_expected.to belong_to(:add_on).with_foreign_key(:subscription_add_on_id).inverse_of(:add_on_purchases) }
    it { is_expected.to belong_to(:namespace) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:add_on) }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:expires_on) }

    it { is_expected.to validate_uniqueness_of(:subscription_add_on_id).scoped_to(:namespace_id) }

    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_numericality_of(:quantity).only_integer.is_greater_than_or_equal_to(1) }

    it { is_expected.to validate_presence_of(:purchase_xid) }
    it { is_expected.to validate_length_of(:purchase_xid).is_at_most(255) }
  end
end
