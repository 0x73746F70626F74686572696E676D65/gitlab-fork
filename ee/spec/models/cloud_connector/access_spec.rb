# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Access, models: true, feature_category: :cloud_connector do
  describe 'validations' do
    let_it_be(:cloud_connector_access) { create(:cloud_connector_access) }

    subject { cloud_connector_access }

    it { is_expected.to validate_presence_of(:data) }
  end

  describe 'callbacks' do
    describe 'after_save' do
      subject(:access) { build(:cloud_connector_access) }

      it 'calls #clear_available_services_cache!' do
        is_expected.to receive(:clear_available_services_cache!)
        access.save!
      end
    end
  end

  describe '#clear_available_services_cache!' do
    # creates CC access data; that will clear the cache before the test starts to avoid flakiness
    let_it_be(:cloud_connector_access) { create(:cloud_connector_access) }

    it 'clears cache' do
      expect(CloudConnector::AvailableServices.access_data_reader)
        .to receive(:read_available_services).and_call_original.twice

      # Get service catalog and memoize the result
      CloudConnector::AvailableServices.available_services

      # Expire the memoization
      cloud_connector_access.clear_available_services_cache!

      # Get service catalog and memoize the result, again.
      CloudConnector::AvailableServices.available_services
    end
  end
end
