# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::InviteRegistration, type: :undefined, feature_category: :onboarding do
  subject { described_class }

  describe '.tracking_label' do
    subject { described_class.tracking_label }

    it { is_expected.to eq('invite_registration') }
  end

  describe '.product_interaction' do
    subject { described_class.product_interaction }

    it { is_expected.to eq('Invited User') }
  end

  describe '.welcome_submit_button_text' do
    subject { described_class.welcome_submit_button_text }

    it { is_expected.to eq(_('Get started!')) }
  end

  describe '.redirect_to_company_form?' do
    it { is_expected.not_to be_redirect_to_company_form }
  end
end
