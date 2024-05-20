# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::MissingServiceData, feature_category: :cloud_connector do
  describe '#free_access?' do
    subject(:free_access?) { described_class.new.free_access? }

    it { is_expected.to be false }
  end

  describe '#allowed_for?' do
    subject(:allowed_for?) { described_class.new.allowed_for?(nil) }

    it { is_expected.to be false }
  end

  describe '#purchased?' do
    subject(:purchased?) { described_class.new.purchased? }

    it { is_expected.to be false }
  end

  describe '#name' do
    subject(:name) { described_class.new.name }

    it { is_expected.to eq(:missing_service) }
  end

  describe '#access_token' do
    subject(:access_token) { described_class.new.access_token }

    it { is_expected.to be_nil }
  end
end
