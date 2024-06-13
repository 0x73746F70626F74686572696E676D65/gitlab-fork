# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::SubscriptionRegistration, type: :undefined, feature_category: :onboarding do
  subject { described_class }

  describe '.tracking_label' do
    subject { described_class.tracking_label }

    it { is_expected.to eq('subscription_registration') }
  end

  describe '.welcome_submit_button_text' do
    subject { described_class.welcome_submit_button_text }

    it { is_expected.to eq(_('Continue')) }
  end

  describe '.setup_for_company_label_text' do
    subject { described_class.setup_for_company_label_text }

    it { is_expected.to eq(_('Who will be using this GitLab subscription?')) }
  end

  describe '.redirect_to_company_form?' do
    it { is_expected.not_to be_redirect_to_company_form }
  end
end
