# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/show.html.haml', feature_category: :system_access do
  let_it_be_with_reload(:user) { create(:user, email: 'user@example.com') }

  let(:page) { Nokogiri::HTML.parse(rendered) }
  let(:credit_card_status) { page.at('#credit-card-status')&.text }
  let(:phone_status) { page.at('#phone-status')&.text }
  let(:phone_number) { page.at('#phone-number')&.text }

  before do
    assign(:user, user)
  end

  it 'does not include credit card validation status' do
    render

    expect(rendered).not_to include('Credit card validated')
    expect(credit_card_status).to be_nil
  end

  it 'does not include phone number validation status' do
    render

    expect(phone_status).to be_nil
  end

  it 'does not show primary email as secondary email - lists primary email only once' do
    render

    expect(rendered).to have_text('user@example.com', count: 1)
  end

  context 'Gitlab.com' do
    before do
      allow(::Gitlab).to receive(:com?).and_return(true)
    end

    it 'includes credit card validation status' do
      render

      expect(credit_card_status).to match(/Validated:\s+No/)
    end

    it 'includes phone number validation status' do
      render

      expect(phone_status).to match(/Validated:\s+No/)
    end

    context 'when user has validated a credit card' do
      let!(:validation) { create(:credit_card_validation, user: user) }

      it 'includes credit card validation status' do
        render

        expect(credit_card_status).to include 'Validated at:'
      end
    end

    context 'when user has validated a phone number' do
      before do
        create(
          :phone_number_validation,
          :validated,
          user: user,
          international_dial_code: 1,
          phone_number: '123456789',
          country: 'US'
        )
        user.reload
      end

      it 'includes phone validation status' do
        render

        expect(phone_status).to include 'Validated at:'
      end

      it 'includes last attempted phone number' do
        render

        expect(phone_number).to include 'Last attempted number:'
        expect(phone_number).to include "+1 123456789 (US)"
      end
    end
  end

  describe 'email verification last sent at' do
    let(:verification_last_sent_at) { page.at('[data-testid="email-verification-last-sent-at"]') }

    context 'when confirmation sent at is set' do
      before do
        user.update!(confirmation_sent_at: Time.zone.parse('2024-04-16 20:15:32 UTC'))
      end

      it 'shows the correct date and time' do
        render

        expect(verification_last_sent_at).to have_content('Email verification last sent at: Apr 16, 2024 8:15pm')
      end
    end

    context 'when confirmation sent at is not set' do
      it 'shows "never"' do
        render

        expect(verification_last_sent_at).to have_content('Email verification last sent at: never')
      end
    end
  end
end
