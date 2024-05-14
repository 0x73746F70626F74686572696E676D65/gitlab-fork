# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::SelfHostedModel, feature_category: :custom_models do
  describe 'validation' do
    subject(:self_hosted_model) { build(:ai_self_hosted_model) }

    it { is_expected.to validate_presence_of(:endpoint) }
    it { is_expected.to validate_presence_of(:model) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to allow_value('http://gitlab.com/s').for(:endpoint) }
    it { is_expected.not_to allow_value('javascript:alert(1)').for(:endpoint) }

    describe '#api_token' do
      let(:token) { 'random_token' }

      it 'ensures that it encrypts api tokens' do
        self_hosted_model.api_token = token
        self_hosted_model.save!

        expect(self_hosted_model.persisted?).to be_truthy
        expect(self_hosted_model.reload.api_token).to eq(token)
        expect(self_hosted_model.reload.encrypted_api_token).not_to include(token)
      end
    end
  end
end
