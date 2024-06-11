# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::TrialRegistration, type: :undefined, feature_category: :onboarding do
  describe '.redirect_to_company_form?' do
    it 'redirects to company form' do
      expect(described_class).to be_redirect_to_company_form
    end
  end
end
