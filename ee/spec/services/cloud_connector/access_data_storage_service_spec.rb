# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::AccessDataStorageService, feature_category: :cloud_connector do
  describe '#execute' do
    let_it_be(:service_data) do
      { "available_services" => [{ "name" => "code_suggestions", "serviceStartTime" => "2024-02-15T00:00:00Z" },
        { "name" => "duo_chat", "serviceStartTime" => nil }] }
    end

    subject(:service) { described_class.new(data).execute }

    shared_examples 'returns an error service response and logs the error' do |error_message|
      it 'returns an error service response' do
        result = service
        expect(result.status).to eq(:error)
        expect(result.message).to eq(error_message)
      end

      it 'logs the error' do
        expect(Gitlab::AppLogger).to receive(:error).with("Cloud Connector Access data update failed: #{error_message}")

        service
      end
    end

    shared_examples 'does not create a new record' do
      it 'does not create a new record' do
        expect { service }.not_to change { CloudConnector::Access.count }
      end
    end

    shared_examples 'does not update the existing record' do
      it 'does not update the existing record' do
        expect { service }.not_to change { CloudConnector::Access.last.data }
      end
    end

    context 'when no records exist' do
      before do
        CloudConnector::Access.delete_all
      end

      context 'when the valid data JSON is provided' do
        let(:data) { service_data }

        it 'creates a new record' do
          expect { service }.to change { CloudConnector::Access.count }.to(1)

          record = CloudConnector::Access.last
          expect(record.data).to eq(data)
        end

        it { is_expected.to be_success }
      end

      context 'when the invalid data JSON is provided' do
        let(:data) { {} }

        include_examples 'does not create a new record'
        include_examples 'returns an error service response and logs the error', "Data can't be blank"
      end

      context 'when nil provided as data' do
        let(:data) { nil }

        include_examples 'does not create a new record'
        include_examples 'returns an error service response and logs the error',
          "Data must be a valid json schema, Data can't be blank"
      end
    end

    context 'when the record exists' do
      let_it_be(:cloud_connector_access) { create(:cloud_connector_access, data: service_data) }

      context 'when the valid data JSON is provided' do
        let(:updated_data) { { "available_services" => [] } }
        let(:data) { updated_data }

        it 'updates the existing record' do
          expect { service }.to change { CloudConnector::Access.last.data }
        end

        include_examples 'does not create a new record'

        it { is_expected.to be_success }
      end

      context 'when invalid JSON is provided' do
        let(:data) { {} }

        include_examples 'does not update the existing record'
        include_examples 'does not create a new record'
        include_examples 'returns an error service response and logs the error', "Data can't be blank"
      end

      context 'when nil provided as data' do
        let(:data) { nil }

        include_examples 'does not update the existing record'
        include_examples 'does not create a new record'
        include_examples 'returns an error service response and logs the error',
          "Data must be a valid json schema, Data can't be blank"
      end
    end
  end
end
