# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchasePolicy, feature_category: :seat_cost_management do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user, owner_of: group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: group) }
  let_it_be(:developer) { create(:user, developer_of: group) }
  let_it_be(:reporter) { create(:user, reporter_of: group) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  describe ':admin_add_on_purchase' do
    let(:policy) { :admin_add_on_purchase }

    context 'when namespace is present' do
      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, namespace: group) }

      # only admin and owner are allowed
      where(:user, :admin_mode, :result) do
        ref(:guest)      | nil   | false
        ref(:reporter)   | nil   | false
        ref(:developer)  | nil   | false
        ref(:maintainer) | nil   | false
        ref(:owner)      | nil   | true
        ref(:admin)      | true  | true
        ref(:admin)      | false | false
      end

      with_them do
        subject { described_class.new(user, add_on_purchase).allowed?(:admin_add_on_purchase) }

        before do
          enable_admin_mode!(user) if admin_mode
        end

        it { is_expected.to eq(result) }
      end
    end

    context 'when namespace is nil, in Self-Managed instance context' do
      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :self_managed) }

      # only admin is allowed
      where(:user, :admin_mode, :result) do
        ref(:guest)      | nil   | false
        ref(:reporter)   | nil   | false
        ref(:developer)  | nil   | false
        ref(:maintainer) | nil   | false
        ref(:owner)      | nil   | false
        ref(:admin)      | true  | true
        ref(:admin)      | false | false
      end

      with_them do
        subject { described_class.new(user, add_on_purchase).allowed?(:admin_add_on_purchase) }

        before do
          enable_admin_mode!(user) if admin_mode
        end

        it { is_expected.to eq(result) }
      end
    end
  end
end
