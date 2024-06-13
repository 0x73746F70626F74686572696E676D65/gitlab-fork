# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::SelfSigned::AvailableServiceData, feature_category: :cloud_connector do
  describe '#access_token' do
    let(:resource) { create(:user) }
    let(:encoded_token_string) { 'token_string' }
    let(:cut_off_date) { 1.month.ago }
    let(:dc_unit_primitives) { [:duo_chat_up1, :duo_chat_up2] }
    let(:duo_pro_scopes) { dc_unit_primitives + [:duo_chat_up3] }
    let(:duo_extra_scopes) { dc_unit_primitives + [:duo_chat_up4] }
    let(:bundled_with) { { "duo_pro" => duo_pro_scopes, "duo_extra" => duo_extra_scopes } }
    let(:backend) { 'gitlab-ai-gateway' }
    let(:available_service_data) { described_class.new(:duo_chat, cut_off_date, bundled_with, backend) }
    let(:extra_claims) { {} }
    let(:expected_token) do
      instance_double('Gitlab::CloudConnector::SelfIssuedToken', encoded: encoded_token_string)
    end

    subject(:access_token) { available_service_data.access_token(resource) }

    shared_examples 'issue a token with scopes' do
      it 'returns the constructed token' do
        expect(Gitlab::CloudConnector::SelfIssuedToken).to receive(:new).with(
          audience: backend,
          subject: Gitlab::CurrentSettings.uuid,
          scopes: scopes,
          extra_claims: extra_claims
        ).and_return(expected_token)

        expect(access_token).to eq(encoded_token_string)
      end
    end

    context 'with free access' do
      let(:cut_off_date) { nil }
      let(:scopes) { duo_pro_scopes | duo_extra_scopes }

      include_examples 'issue a token with scopes'
    end

    context 'when passing extra claims' do
      let(:extra_claims) { { custom: 123 } }
      let(:scopes) { duo_pro_scopes }

      subject(:access_token) { available_service_data.access_token(resource, extra_claims: extra_claims) }

      before do
        allow(available_service_data).to receive(:scopes_for).and_return(duo_pro_scopes)
      end

      include_examples 'issue a token with scopes'
    end

    context 'when passed resource is a User' do
      context 'with duo_pro purchased' do
        let(:scopes) { duo_pro_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases_assigned_to, :uniq_add_on_names).and_return(%w[duo_pro])
        end

        include_examples 'issue a token with scopes'
      end

      context 'with code_suggestions purchased' do
        let(:scopes) { duo_pro_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases_assigned_to, :uniq_add_on_names)
            .and_return(%w[code_suggestions])
        end

        include_examples 'issue a token with scopes'
      end

      context 'with duo_extra purchased' do
        let(:scopes) { duo_extra_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases_assigned_to, :uniq_add_on_names).and_return(%w[duo_extra])
        end

        include_examples 'issue a token with scopes'
      end

      context 'with both duo_pro and duo_extra purchased' do
        let(:scopes) { duo_pro_scopes | duo_extra_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases_assigned_to, :uniq_add_on_names)
            .and_return(%w[duo_pro duo_extra])
        end

        include_examples 'issue a token with scopes'
      end
    end

    context 'when passed resource is not a User' do
      let(:resource) { nil }

      context 'with duo_pro purchased' do
        let(:scopes) { duo_pro_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases, :uniq_add_on_names).and_return(%w[duo_pro])
        end

        include_examples 'issue a token with scopes'
      end

      context 'with duo_extra purchased' do
        let(:scopes) { duo_extra_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases, :uniq_add_on_names).and_return(%w[duo_extra])
        end

        include_examples 'issue a token with scopes'
      end

      context 'with both duo_pro and duo_extra purchased' do
        let(:scopes) { duo_pro_scopes | duo_extra_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases, :uniq_add_on_names).and_return(%w[duo_pro duo_extra])
        end

        include_examples 'issue a token with scopes'
      end
    end
  end
end
