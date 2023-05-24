# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ServiceDesk::CustomEmailVerifications::CreateService, feature_category: :service_desk do
  describe '#execute' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:user) { create(:user) }

    let!(:credential) { create(:service_desk_custom_email_credential, project: project) }

    let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }
    let(:message) { instance_double(Mail::Message) }

    let(:service) { described_class.new(project: project, current_user: user) }

    before do
      allow(message_delivery).to receive(:deliver_later)
      allow(Notify).to receive(:service_desk_verification_triggered_email).and_return(message_delivery)

      # We send verification email directly
      allow(message).to receive(:deliver)
      allow(Notify).to receive(:service_desk_custom_email_verification_email).and_return(message)
    end

    shared_examples 'a verification process that exits early' do
      it 'aborts verification process and exits early', :aggregate_failures do
        # Because we exit early it should not send any verification or notification emails
        expect(service).to receive(:setup_and_deliver_verification_email).exactly(0).times
        expect(Notify).to receive(:service_desk_verification_triggered_email).exactly(0).times

        response = service.execute

        expect(response).to be_error
      end
    end

    shared_examples 'a verification process with ramp up error' do |error, error_identifier|
      it 'aborts verification process', :aggregate_failures do
        allow(message).to receive(:deliver).and_raise(error)

        # Creates one verification email
        expect(Notify).to receive(:service_desk_custom_email_verification_email).once

        # Correct amount of notification emails were sent
        expect(Notify).to receive(:service_desk_verification_triggered_email).exactly(project.owners.size + 1).times

        # Correct amount of result notification emails were sent
        expect(Notify).to receive(:service_desk_verification_result_email).exactly(project.owners.size + 1).times

        response = service.execute

        expect(response).to be_error
        expect(response.reason).to eq error_identifier

        expect(settings).not_to be_custom_email_enabled
        expect(settings.custom_email_verification.triggered_at).not_to be_nil
        expect(settings.custom_email_verification).to have_attributes(
          token: nil,
          triggerer: user,
          error: error_identifier,
          state: 'failed'
        )
      end
    end

    it_behaves_like 'a verification process that exits early'

    context 'when feature flag :service_desk_custom_email is disabled' do
      before do
        stub_feature_flags(service_desk_custom_email: false)
      end

      it_behaves_like 'a verification process that exits early'
    end

    context 'when service desk setting exists' do
      let(:settings) { create(:service_desk_setting, project: project, custom_email: 'user@example.com') }
      let(:service) { described_class.new(project: settings.project, current_user: user) }

      it 'aborts verification process and exits early', :aggregate_failures do
        # Because we exit early it should not send any verification or notification emails
        expect(service).to receive(:setup_and_deliver_verification_email).exactly(0).times
        expect(Notify).to receive(:service_desk_verification_triggered_email).exactly(0).times

        response = service.execute
        settings.reload

        expect(response).to be_error

        expect(settings.custom_email_enabled).to be false
        # Because service should normally add initial verification object
        expect(settings.custom_email_verification).to be nil
      end

      context 'when user has maintainer role in project' do
        before do
          project.add_maintainer(user)
        end

        it 'initiates verification process successfully', :aggregate_failures do
          # Creates one verification email
          expect(Notify).to receive(:service_desk_custom_email_verification_email).once

          # Check whether the correct amount of notification emails were sent
          expect(Notify).to receive(:service_desk_verification_triggered_email).exactly(project.owners.size + 1).times

          response = service.execute

          settings.reload
          verification = settings.custom_email_verification

          expect(response).to be_success

          expect(settings.custom_email_enabled).to be false

          expect(verification).to be_started
          expect(verification.token).not_to be_nil
          expect(verification.triggered_at).not_to be_nil
          expect(verification).to have_attributes(
            triggerer: user,
            error: nil
          )
        end

        context 'when providing invalid SMTP credentials' do
          before do
            allow(Notify).to receive(:service_desk_verification_result_email).and_return(message_delivery)
          end

          it_behaves_like 'a verification process with ramp up error', SocketError, 'smtp_host_issue'
          it_behaves_like 'a verification process with ramp up error', OpenSSL::SSL::SSLError, 'smtp_host_issue'
          it_behaves_like 'a verification process with ramp up error',
            Net::SMTPAuthenticationError.new('Invalid username or password'), 'invalid_credentials'
        end
      end
    end
  end
end
