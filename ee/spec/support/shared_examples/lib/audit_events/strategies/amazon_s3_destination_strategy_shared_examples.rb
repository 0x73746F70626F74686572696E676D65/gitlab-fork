# frozen_string_literal: true

RSpec.shared_examples 'validate Amazon S3 destination strategy' do
  describe '#track_and_stream' do
    let(:instance) { described_class.new(event_type, event) }
    let(:request_body) { { key: "value", id: event.id }.to_json }

    subject(:track_and_stream) { instance.send(:track_and_stream, destination) }

    before do
      allow(instance).to receive(:request_body).and_return(request_body)
    end

    context 'when Amazon S3 configuration exists' do
      it 'tracks audit event count and calls Aws::S3::Client', :freeze_time do
        time_in_ms = (Time.now.to_f * 1000).to_i
        date = Date.current.strftime("%Y/%m")

        expect(instance).to receive(:track_audit_event)

        allow_next_instance_of(Aws::S3::Client) do |s3_client|
          expect(s3_client).to receive(:put_object).with(
            {
              key: "#{event['entity_type'].downcase}/#{date}/#{event_type}_#{event['id']}_#{time_in_ms}.json",
              bucket: destination.bucket_name,
              content_type: 'application/json',
              body: request_body
            }
          )
        end

        track_and_stream
      end
    end

    context 'when entity type is Gitlab::Audit::InstanceScope' do
      let_it_be(:event) { create(:audit_event, :instance_event) }
      let_it_be(:event_type) { 'application_setting_updated' }

      it 'saves the json inside the instance directory on S3', :freeze_time do
        time_in_ms = (Time.now.to_f * 1000).to_i
        date = Date.current.strftime("%Y/%m")

        expect(instance).to receive(:track_audit_event)

        allow_next_instance_of(Aws::S3::Client) do |s3_client|
          expect(s3_client).to receive(:put_object).with(
            {
              key: "instance/#{date}/#{event_type}_#{event['id']}_#{time_in_ms}.json",
              bucket: destination.bucket_name,
              content_type: 'application/json',
              body: request_body
            }
          )
        end

        track_and_stream
      end
    end

    context 'when entity type is Namespaces::UserNamespace' do
      let_it_be(:event) { create(:audit_event, entity_type: 'Namespaces::UserNamespace') }
      let_it_be(:event_type) { 'project_destroyed' }

      it 'saves the json inside the user directory on S3', :freeze_time do
        time_in_ms = (Time.now.to_f * 1000).to_i
        date = Date.current.strftime("%Y/%m")

        expect(instance).to receive(:track_audit_event)

        allow_next_instance_of(Aws::S3::Client) do |s3_client|
          expect(s3_client).to receive(:put_object).with(
            {
              key: "user/#{date}/#{event_type}_#{event['id']}_#{time_in_ms}.json",
              bucket: destination.bucket_name,
              content_type: 'application/json',
              body: request_body
            }
          )
        end

        track_and_stream
      end
    end

    context 'when entity type has special characters' do
      let_it_be(:event) { create(:audit_event, entity_type: 'Random::RSpec::Scope') }
      let_it_be(:event_type) { 'project_destroyed' }

      it 'replaces all the non alpha numeric characters with underscore and save to S3', :freeze_time do
        time_in_ms = (Time.now.to_f * 1000).to_i
        date = Date.current.strftime("%Y/%m")

        expect(instance).to receive(:track_audit_event)

        allow_next_instance_of(Aws::S3::Client) do |s3_client|
          expect(s3_client).to receive(:put_object).with(
            {
              key: "random_rspec_scope/#{date}/#{event_type}_#{event['id']}_#{time_in_ms}.json",
              bucket: destination.bucket_name,
              content_type: 'application/json',
              body: request_body
            }
          )
        end

        track_and_stream
      end
    end
  end
end
