# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::InviteRegistration, type: :undefined, feature_category: :onboarding do
  describe '.redirect_to_company_form?' do
    it 'does not redirect to company form' do
      expect(described_class).not_to be_redirect_to_company_form
    end
  end
end
