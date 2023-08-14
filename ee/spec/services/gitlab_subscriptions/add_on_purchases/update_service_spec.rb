# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::UpdateService, :aggregate_failures, feature_category: :saas_provisioning do
  describe '#execute' do
    let_it_be(:admin) { build(:user, :admin) }
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
    let_it_be(:purchase_xid) { 'S-A00000001' }

    let(:params) do
      {
        quantity: 10,
        expires_on: (Date.current + 1.year).to_s,
        purchase_xid: purchase_xid
      }
    end

    subject(:result) { described_class.new(user, namespace, add_on, params).execute }

    context 'with a non-admin user' do
      let(:non_admin) { build(:user) }
      let(:user) { non_admin }

      it 'raises an error' do
        expect { result }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    context 'with an admin user' do
      let(:user) { admin }

      context 'when no record exists' do
        it 'returns an error' do
          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq(
            'Add-on purchase for namespace and add-on does not exist, use the create endpoint instead'
          )
        end
      end

      context 'when a record exists' do
        let_it_be(:expires_on) { Date.current + 6.months }
        let_it_be(:add_on_purchase) do
          create(
            :gitlab_subscription_add_on_purchase,
            namespace: namespace,
            add_on: add_on,
            quantity: 5,
            expires_on: expires_on,
            purchase_xid: purchase_xid
          )
        end

        it 'returns a success' do
          expect(result[:status]).to eq(:success)
        end

        it 'updates the found record' do
          expect(result[:add_on_purchase]).to be_persisted
          expect(result[:add_on_purchase]).to eq(add_on_purchase)
          expect do
            result
            add_on_purchase.reload
          end.to change { add_on_purchase.quantity }.from(5).to(10)
            .and change { add_on_purchase.expires_on }.from(expires_on).to(params[:expires_on].to_date)
        end

        context 'when creating the record failed' do
          let(:params) { super().merge(quantity: 0) }

          it 'returns an error' do
            expect { result }.not_to change { add_on_purchase.quantity }

            expect(result[:status]).to eq(:error)
            expect(result[:message]).to eq('Add-on purchase could not be saved')
            expect(result[:add_on_purchase]).to be_an_instance_of(GitlabSubscriptions::AddOnPurchase)
            expect(result[:add_on_purchase]).to eq(add_on_purchase)
          end
        end
      end
    end
  end
end
