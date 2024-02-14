# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PhoneVerification::TelesignCallbacksController, feature_category: :instance_resiliency do
  describe 'POST #notify' do
    subject(:do_request) { post phone_verification_telesign_callback_path }

    context 'when callback request is not valid (authentication failed)' do
      it 'does not log and returns not found status', :aggregate_failures do
        expect_next_instance_of(
          Telesign::TransactionCallback,
          an_instance_of(ActionDispatch::Request),
          an_instance_of(ActionController::Parameters)
        ) do |callback|
          allow(callback).to receive(:valid?).and_return(false)
          expect(callback).not_to receive(:log)
        end

        do_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when callback request is valid' do
      it 'logs and returns ok status', :aggregate_failures do
        expect_next_instance_of(
          Telesign::TransactionCallback,
          an_instance_of(ActionDispatch::Request),
          an_instance_of(ActionController::Parameters)
        ) do |callback|
          allow(callback).to receive(:valid?).and_return(true)
          expect(callback).to receive(:log)
        end

        do_request

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when origin country of user is blocked in Telesign' do
      shared_examples 'does not invalidate verification_state_identity_verification_path cache' do
        it 'does not invalidate verification_state_identity_verification_path cache' do
          expect(Gitlab::EtagCaching).not_to receive(:new)

          do_request
        end
      end

      shared_examples 'does not exempt the user' do
        it 'does not exempt the user' do
          expect { do_request }.not_to change { user.exempt_from_phone_number_verification? }
        end
      end

      before do
        allow_next_instance_of(
          Telesign::TransactionCallback,
          an_instance_of(ActionDispatch::Request),
          an_instance_of(ActionController::Parameters)
        ) do |callback|
          allow(callback).to receive(:valid?).and_return(true)
          allow(callback).to receive(:user).and_return(user)
          allow(callback).to receive(:log)

          payload = instance_double(Telesign::TransactionCallbackPayload, { country_blocked?: true })
          allow(callback).to receive(:payload).and_return(payload)
        end
      end

      context 'when no user is associated with the callback' do
        let(:user) { nil }

        it_behaves_like 'does not invalidate verification_state_identity_verification_path cache'
      end

      context 'when a user is associated with the callback' do
        let(:user) { create(:user) }

        before do
          allow(user).to receive(:offer_phone_number_exemption?).and_return(true)
          stub_feature_flags(auto_request_phone_number_verification_exemption: user)
        end

        it 'exempts the user' do
          expect { do_request }.to change { user.exempt_from_phone_number_verification? }.from(false).to(true)
        end

        it 'invalidates verification_state_identity_verification_path cache' do
          expect_next_instance_of(Gitlab::EtagCaching::Store) do |store|
            expect(store).to receive(:touch).with(verification_state_identity_verification_path)
          end

          do_request
        end

        context 'when user is not qualified for phone number exemption offer' do
          before do
            allow(user).to receive(:offer_phone_number_exemption?).and_return(false)
          end

          it_behaves_like 'does not exempt the user'
          it_behaves_like 'does not invalidate verification_state_identity_verification_path cache'
        end

        context 'when auto_request_phone_number_verification_exemption feature flag is disabled for user' do
          before do
            stub_feature_flags(auto_request_phone_number_verification_exemption: create(:user))
          end

          it_behaves_like 'does not exempt the user'
          it_behaves_like 'does not invalidate verification_state_identity_verification_path cache'
        end
      end
    end
  end
end
