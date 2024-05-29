# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::AvailableServices, feature_category: :cloud_connector do
  before do
    described_class.clear_memoization(:access_data_reader)
    described_class.clear_memoization(:available_services)
  end

  context 'when .com', :saas do
    it 'includes GitlabCom::AccessDataReader' do
      expect(described_class.access_data_reader)
        .to be_a_kind_of(CloudConnector::GitlabCom::AccessDataReader)
    end
  end

  context 'when self_managed' do
    it 'includes SelfManaged::AccessDataReader' do
      expect(described_class.access_data_reader)
        .to be_a_kind_of(CloudConnector::SelfManaged::AccessDataReader)
    end
  end

  describe '.find_by_name' do
    it 'reads available service' do
      available_services = { duo_chat: CloudConnector::BaseAvailableServiceData.new(:duo_chat, nil, nil) }
      expect(described_class.access_data_reader).to receive(:read_available_services).and_return(available_services)

      service = described_class.find_by_name(:duo_chat)

      expect(service.name).to eq(:duo_chat)
    end

    context 'when available_services is empty' do
      it 'returns null service data' do
        expect(described_class.access_data_reader).to receive(:read_available_services).and_return([])

        service = described_class.find_by_name(:duo_chat)

        expect(service.name).to eq(:missing_service)
        expect(service).to be_instance_of(CloudConnector::MissingServiceData)
      end
    end
  end

  describe '#available_services' do
    subject(:available_services) { described_class.available_services }

    it 'caches the available services' do
      expect(described_class.access_data_reader).to receive(:read_available_services).and_call_original.once

      2.times do
        available_services
      end
    end
  end
end
