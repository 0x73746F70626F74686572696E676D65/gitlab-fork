# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServiceDesk::CustomEmailVerifications::UpdateService, feature_category: :service_desk do
  describe '#execute' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:user) { create(:user) }

    let!(:credential) { create(:service_desk_custom_email_credential, project: project) }
    let(:settings) { create(:service_desk_setting, project: project, custom_email: 'custom-support-email@example.com') }

    let(:mail_object) { nil }
    let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }
    let(:service) { described_class.new(project: settings.project, params: { mail: mail_object }) }

    before do
      allow(message_delivery).to receive(:deliver_later)
      allow(Notify).to receive(:service_desk_verification_result_email).and_return(message_delivery)
    end

    shared_examples 'a failing verification process' do |expected_error_identifier|
      it 'refuses to verify and sends result emails' do
        expect(Notify).to receive(:service_desk_verification_result_email).twice

        response = described_class.new(project: settings.project, params: { mail: mail_object }).execute

        settings.reset
        verification.reset

        expect(response).to be_error
        expect(settings).not_to be_custom_email_enabled
        expect(verification).to be_failed

        expect(response.reason).to eq expected_error_identifier
        expect(verification.error).to eq expected_error_identifier
      end
    end

    shared_examples 'an early exit from the verification process' do |expected_state|
      it 'exits early' do
        expect(Notify).to receive(:service_desk_verification_result_email).exactly(0).times

        response = service.execute

        settings.reset
        verification.reset

        expect(response).to be_error
        expect(settings).not_to be_custom_email_enabled
        expect(verification.state).to eq expected_state
      end
    end

    it 'exits early' do
      expect(Notify).to receive(:service_desk_verification_result_email).exactly(0).times

      response = service.execute

      settings.reset

      expect(response).to be_error
      expect(settings).not_to be_custom_email_enabled
    end

    context 'when feature flag :service_desk_custom_email is disabled' do
      before do
        stub_feature_flags(service_desk_custom_email: false)
      end

      it 'exits early' do
        expect(Notify).to receive(:service_desk_verification_result_email).exactly(0).times

        response = service.execute

        expect(response).to be_error
      end
    end

    context 'when verification exists' do
      let!(:verification) { create(:service_desk_custom_email_verification, project: project) }

      context 'when we do not have a verification email' do
        # Raise if verification started but no email provided
        it_behaves_like 'a failing verification process', 'mail_not_received_within_timeframe'

        context 'when already verified' do
          before do
            verification.mark_as_finished!
          end

          it_behaves_like 'an early exit from the verification process', 'finished'
        end

        context 'when we already have an error' do
          before do
            verification.mark_as_failed!(:smtp_host_issue)
          end

          it_behaves_like 'an early exit from the verification process', 'failed'
        end
      end

      context 'when we have a verification email' do
        before do
          verification.update!(token: 'ZROT4ZZXA-Y6') # token from email fixture
        end

        let(:email_raw) { email_fixture('emails/service_desk_custom_email_address_verification.eml') }
        let(:mail_object) { Mail::Message.new(email_raw) }

        it 'verifies and sends result emails' do
          expect(Notify).to receive(:service_desk_verification_result_email).twice

          response = service.execute

          settings.reset
          verification.reset

          expect(response).to be_success
          expect(settings).not_to be_custom_email_enabled
          expect(verification).to be_finished
        end

        context 'and verification tokens do not match' do
          before do
            verification.update!(token: 'XXXXXXZXA-XX')
          end

          it_behaves_like 'a failing verification process', 'incorrect_token'
        end

        context 'and from address does not match with custom email' do
          before do
            settings.update!(custom_email: 'some-other@example.com')
          end

          it_behaves_like 'a failing verification process', 'incorrect_from'
        end

        context 'and timeframe for receiving the email is over' do
          before do
            verification.update!(triggered_at: 40.minutes.ago)
          end

          it_behaves_like 'a failing verification process', 'mail_not_received_within_timeframe'
        end
      end
    end
  end
end
