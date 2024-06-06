# frozen_string_literal: true

RSpec.shared_examples 'includes ExternallyStreamable concern' do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:config) }
    it { is_expected.to validate_presence_of(:secret_token) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to be_a(AuditEvents::ExternallyStreamable) }
    it { is_expected.to validate_length_of(:name).is_at_most(72) }

    context 'when category' do
      it 'is valid' do
        expect(destination).to be_valid
      end

      it 'is nil' do
        destination.category = nil

        expect(destination).not_to be_valid
        expect(destination.errors.full_messages)
          .to match_array(["Category can't be blank"])
      end

      it 'is invalid' do
        expect { destination.category = 'invalid' }.to raise_error(ArgumentError)
      end
    end

    it_behaves_like 'having unique enum values'

    context 'when config' do
      it 'is invalid' do
        destination.config = 'hello'

        expect(destination).not_to be_valid
        expect(destination.errors.full_messages).to include('Config must be a valid json schema')
      end
    end

    context 'when creating without a name' do
      before do
        allow(SecureRandom).to receive(:uuid).and_return('12345678')
      end

      it 'assigns a default name' do
        destination = build(model_factory_name, name: nil)

        expect(destination).to be_valid
        expect(destination.name).to eq('Destination_12345678')
      end
    end

    context 'when category is http' do
      context 'for config schema validation' do
        using RSpec::Parameterized::TableSyntax

        subject(:destination) do
          build(model_factory_name, config: { url: http_url, headers: http_headers })
        end

        let(:more_than_allowed_headers) { {} }

        let(:large_string) { "a" * 256 }
        let(:large_url) { "http://#{large_string}.com" }
        let(:header_hash1) { { key1: { value: 'value1', active: true }, key2: { value: 'value2', active: false } } }
        let(:header_hash2) { { key1: { value: 'value1', active: true }, key2: { value: 'value2', active: false } } }

        before do
          21.times do |i|
            more_than_allowed_headers["Key#{i}"] = { value: "Value#{i}", active: true }
          end
        end

        where(:http_url, :http_headers, :is_valid) do
          nil                   | nil                                                   | false
          'http://example.com'  | nil                                                   | true
          ref(:large_url)       | nil                                                   | false
          'https://example.com' | nil                                                   | true
          'ftp://example.com'   | nil                                                   | false
          nil                   | { key1: 'value1' }                                    | false
          'http://example.com'  | { key1: { value: 'value1', active: true } }           | true
          'http://example.com'  | { key1: { value: ref(:large_string), active: true } } | false
          'http://example.com'  | { key1: { value: 'value1', active: false } }          | true
          'http://example.com'  | {}                                                    | false
          'http://example.com'  | ref(:header_hash1)                                    | true
          'http://example.com'  | { key1: 'value1' }                                    | false
          'http://example.com'  | ref(:header_hash2)                                    | true
          'http://example.com'  | ref(:more_than_allowed_headers)                       | false
        end

        with_them do
          it do
            expect(destination.valid?).to eq(is_valid)
          end
        end
      end
    end

    context 'when category is aws' do
      context 'for config schema validation' do
        using RSpec::Parameterized::TableSyntax

        subject(:destination) do
          build(:audit_events_group_external_streaming_destination, :aws,
            config: { accessKeyXid: access_key, bucketName: bucket, awsRegion: region })
        end

        where(:access_key, :bucket, :region, :is_valid) do
          SecureRandom.hex(8)   | SecureRandom.hex(8)   | SecureRandom.hex(8)    | true
          nil                   | nil                   | nil                    | false
          SecureRandom.hex(8)   | SecureRandom.hex(8)   | nil                    | false
          SecureRandom.hex(8)   | nil                   | SecureRandom.hex(8)    | false
          nil                   | SecureRandom.hex(8)   | SecureRandom.hex(8)    | false
          SecureRandom.hex(7)   | SecureRandom.hex(8)   | SecureRandom.hex(8)    | false
          SecureRandom.hex(8)   | SecureRandom.hex(35) | SecureRandom.hex(8)    | false
          SecureRandom.hex(8)   | SecureRandom.hex(8) | SecureRandom.hex(26)    | false
          "access-id-with-hyphen" | SecureRandom.hex(8) | SecureRandom.hex(8) | false
          SecureRandom.hex(8) | "bucket/logs/test" | SecureRandom.hex(8) | false
        end

        with_them do
          it do
            expect(destination.valid?).to eq(is_valid)
          end
        end
      end
    end

    context 'when category is gcp' do
      context 'for config schema validation' do
        using RSpec::Parameterized::TableSyntax

        subject(:destination) do
          build(model_factory_name, :gcp,
            config: { googleProjectIdName: project_id, clientEmail: client_email, logIdName: log_id }.compact)
        end

        where(:project_id, :client_email, :log_id, :is_valid) do
          "valid-project-id"     | "abcd@example.com"                         | "audit-events"        | true
          "valid-project-id-1"   | "abcd@example.com"                         | "audit-events"        | true
          "invalid_project_id"   | "abcd@example.com"                         | "audit-events"        | false
          "invalid-project-id-"  | "abcd@example.com"                         | "audit-events"        | false
          "Invalid-project-id"   | "abcd@example.com"                         | "audit-events"        | false
          "1-invalid-project-id" | "abcd@example.com"                         | "audit-events"        | false
          "-invalid-project-id"  | "abcd@example.com"                         | "audit-events"        | false
          "small"                | "abcd@example.com"                         | "audit-events"        | false
          SecureRandom.hex(16)   | "abcd@example.com"                         | "audit-events"        | false

          "valid-project-id"     | "valid_email+mail@mail.com"                | "audit-events"        | true
          "valid-project-id"     | "invalid_email"                            | "audit-events"        | false
          "valid-project-id"     | "invalid@.com"                             | "audit-events"        | false
          "valid-project-id"     | "invalid..com"                             | "audit-events"        | false
          "valid-project-id"     | "abcd#{SecureRandom.hex(120)}@example.com" | "audit-events"        | false

          "valid-project-id"     | "abcd@example.com"                         | "audit_events"        | true
          "valid-project-id"     | "abcd@example.com"                         | "audit.events"        | true
          "valid-project-id"     | "abcd@example.com"                         | "AUDIT_EVENTS"        | true
          "valid-project-id"     | "abcd@example.com"                         | "audit_events/123"    | true
          "valid-project-id"     | "abcd@example.com"                         | "AUDIT_EVENT@"        | false
          "valid-project-id"     | "abcd@example.com"                         | "AUDIT_EVENT$"        | false
          "valid-project-id"     | "abcd@example.com"                         | "#AUDIT_EVENT"        | false
          "valid-project-id"     | "abcd@example.com"                         | "%audit_events/123"   | false
          "valid-project-id"     | "abcd@example.com"                         | SecureRandom.hex(256) | false

          nil                    | nil                                        | nil                   | false
          "valid-project-id"     | "abcd@example.com"                         | nil                   | true
          "valid-project-id"     | nil                                        | "audit-events"        | false
          nil                    | "abcd@example.com"                         | "audit-events"        | false
        end

        with_them do
          it do
            expect(destination.valid?).to eq(is_valid)
          end
        end
      end
    end

    describe "#assign_default_log_id" do
      context 'when category is gcp' do
        context 'when log id is provided' do
          it 'does not assign default value' do
            destination = create(model_factory_name,
              :gcp,
              config: {
                googleProjectIdName: "project-id",
                clientEmail: "abcd@email.com",
                logIdName: 'non-default-log'
              }
            )

            expect(destination).to be_valid
            expect(destination.errors).to be_empty
            expect(destination.config['logIdName']).to eq('non-default-log')
          end
        end

        context 'when log id is not provided' do
          it 'assigns default value' do
            destination = create(model_factory_name,
              :gcp,
              config: {
                googleProjectIdName: "project-id",
                clientEmail: "abcd@email.com"
              }
            )

            expect(destination).to be_valid
            expect(destination.errors).to be_empty
            expect(destination.config['logIdName']).to eq('audit-events')
          end
        end
      end

      context 'when category is not gcp' do
        it 'does not add logIdName field to config' do
          destination = create(model_factory_name, config: { url: "https://www.example.com" })

          expect(destination).to be_valid
          expect(destination.config.keys).not_to include('logIdName')
        end
      end
    end
  end
end
