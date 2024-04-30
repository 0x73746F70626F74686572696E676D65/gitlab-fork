# frozen_string_literal: true

RSpec.shared_examples 'access data reader' do
  describe '#read_available_services' do
    subject(:available_services) { described_class.new.read_available_services }

    it 'creates AvailableServiceData with correct params' do
      arguments_map.each do |name, args|
        expect(available_service_data_class).to receive(:new).with(name, *args).and_call_original
      end

      available_services
    end

    it 'returns a hash containing all available services', :aggregate_failures do
      expect(available_services.keys).to match_array(arguments_map.keys)

      expect(available_services.values).to all(be_instance_of(available_service_data_class))
    end
  end
end
