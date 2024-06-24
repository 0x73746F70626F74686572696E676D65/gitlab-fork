# frozen_string_literal: true

RSpec.shared_examples 'validate google cloud logging destination strategy' do
  describe '#track_and_stream' do
    context 'when an instance google cloud logging configuration exists' do
      let(:instance) { described_class.new(event_type, event) }
      let(:expected_log_entry) do
        [{ entries: {
          'logName' => destination.full_log_path,
          'resource' => {
            'type' => 'global'
          },
          'severity' => 'INFO',
          'jsonPayload' => ::Gitlab::Json.parse(request_body)
        } }.to_json]
      end

      subject(:track_and_stream) { instance.send(:track_and_stream, destination) }

      before do
        allow_next_instance_of(AuditEvents::GoogleCloud::LoggingService::Logger) do |instance|
          allow(instance).to receive(:log).and_return(nil)
        end
        allow(instance).to receive(:request_body).and_return(request_body)
      end

      it 'tracks audit event count and calls logger' do
        expect(instance).to receive(:track_audit_event)

        allow_next_instance_of(AuditEvents::GoogleCloud::LoggingService::Logger) do |logger|
          expect(logger).to receive(:log).with(destination.client_email, destination.private_key, expected_log_entry)
        end

        track_and_stream
      end
    end
  end
end
