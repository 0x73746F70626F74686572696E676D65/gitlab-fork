# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::PurchaseUrlBuilder, feature_category: :subscription_management do
  describe '#customers_dot_flow?' do
    let_it_be(:current_user) { create(:user) }
    let(:namespace) { build(:group) }

    subject(:builder) do
      described_class.new(current_user: current_user, plan_id: 'plan-id', namespace: namespace)
    end

    context 'when the migrate_purchase_flows_for_existing_customers feature is disabled' do
      it 'returns false' do
        stub_feature_flags(migrate_purchase_flows_for_existing_customers: false)

        expect(builder.customers_dot_flow?).to eq false
      end
    end

    context 'when the migrate_purchase_flows_for_existing_customers feature is enabled' do
      before do
        stub_feature_flags(migrate_purchase_flows_for_existing_customers: true)
      end

      context 'when the user does not have a valid billing account' do
        before do
          allow(Gitlab::SubscriptionPortal::Client).to receive(:get_billing_account_details).and_return({
            success: true, billing_account_details: { "billingAccount" => { "zuoraAccountName" => nil } }
          })
        end

        it 'returns false' do
          expect(builder.customers_dot_flow?).to eq false
        end
      end

      context 'when a namespace is not provided' do
        let(:namespace) { nil }

        it 'returns false' do
          expect(builder.customers_dot_flow?).to eq false
        end
      end

      context 'when the user has a valid billing account' do
        before do
          allow(Gitlab::SubscriptionPortal::Client).to receive(:get_billing_account_details).and_return({
            success: true, billing_account_details: { "billingAccount" => { "zuoraAccountName" => "sample-account" } }
          })
        end

        it 'returns true' do
          expect(builder.customers_dot_flow?).to eq true
        end
      end
    end
  end

  describe '#build' do
    let(:subscription_portal_url) { Gitlab::Routing.url_helpers.subscription_portal_url }

    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group) }

    context 'when the migrate_purchase_flows_for_existing_customers feature is disabled' do
      before do
        stub_feature_flags(migrate_purchase_flows_for_existing_customers: false)
      end

      context 'when the gitlab purchase flow supports this namespace' do
        it 'generates the gitlab purchase flow URL' do
          builder = described_class.new(current_user: user, plan_id: 'plan-id', namespace: namespace)

          expect(builder.build).to eq "/-/subscriptions/new?namespace_id=#{namespace.id}&plan_id=plan-id"
        end
      end

      context 'when supplied additional parameters' do
        it 'includes the params in the URL' do
          builder = described_class.new(current_user: user, plan_id: 'plan-id', namespace: namespace)

          expect(builder.build(source: 'source'))
            .to eq "/-/subscriptions/new?namespace_id=#{namespace.id}&plan_id=plan-id&source=source"
        end
      end

      context 'when the current_user does not have a last name' do
        it 'generates the customers dot flow URL' do
          builder = described_class.new(
            current_user: build(:user, name: 'First'),
            plan_id: 'plan-id',
            namespace: namespace
          )

          expect(builder.build)
            .to eq "#{subscription_portal_url}/subscriptions/new?gl_namespace_id=#{namespace.id}&plan_id=plan-id"
        end
      end

      context 'when the namespace is a user namespace' do
        it 'generates the customers dot flow URL' do
          user_namespace = create(:user_namespace)

          builder = described_class.new(current_user: user, plan_id: 'plan-id', namespace: user_namespace)

          expect(builder.build)
            .to eq "#{subscription_portal_url}/subscriptions/new?gl_namespace_id=#{user_namespace.id}&plan_id=plan-id"
        end
      end
    end

    context 'when the migrate_purchase_flows_for_existing_customers feature is enabled' do
      subject(:builder) { described_class.new(current_user: user, plan_id: 'plan-id', namespace: namespace) }

      before do
        stub_feature_flags(migrate_purchase_flows_for_existing_customers: true)
        allow(Gitlab::SubscriptionPortal::Client).to receive(:get_billing_account_details).and_return({
          success: true, billing_account_details: { "billingAccount" => { "zuoraAccountName" => "sample-account" } }
        })
      end

      it 'generates the customers dot flow URL' do
        expect(builder.build)
          .to eq "#{subscription_portal_url}/subscriptions/new?gl_namespace_id=#{namespace.id}&plan_id=plan-id"
      end

      context 'when supplied additional parameters' do
        it 'includes the params in the URL' do
          expected_url = "#{subscription_portal_url}/subscriptions/new?gl_namespace_id=#{namespace.id}&" \
            "plan_id=plan-id&source=source"

          expect(builder.build(source: 'source')).to eq expected_url
        end
      end
    end
  end
end
