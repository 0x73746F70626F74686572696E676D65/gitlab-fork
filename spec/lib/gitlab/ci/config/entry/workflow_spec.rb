# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config::Entry::Workflow do
  let(:factory) { Gitlab::Config::Entry::Factory.new(described_class).value(rules_hash) }
  let(:config)  { factory.create! }

  describe 'validations' do
    context 'when work config value is a string' do
      let(:rules_hash) { 'build' }

      describe '#valid?' do
        it 'is invalid' do
          expect(config).not_to be_valid
        end

        it 'attaches an error specifying that workflow should point to a hash' do
          expect(config.errors).to include('workflow config should be a hash')
        end
      end

      describe '#value' do
        it 'returns the invalid configuration' do
          expect(config.value).to eq(rules_hash)
        end
      end
    end

    context 'when work config value is a hash' do
      let(:rules_hash) { { rules: [{ if: '$VAR' }] } }

      describe '#valid?' do
        it 'is valid' do
          expect(config).to be_valid
        end

        it 'attaches no errors' do
          expect(config.errors).to be_empty
        end
      end

      describe '#value' do
        it 'returns the config' do
          expect(config.value).to eq(rules_hash)
        end
      end

      context 'with an invalid key' do
        let(:rules_hash) { { trash: [{ if: '$VAR' }] } }

        describe '#valid?' do
          it 'is invalid' do
            expect(config).not_to be_valid
          end

          it 'attaches an error specifying the unknown key' do
            expect(config.errors).to include('workflow config contains unknown keys: trash')
          end
        end

        describe '#value' do
          it 'returns the invalid configuration' do
            expect(config.value).to eq(rules_hash)
          end
        end
      end

      context 'with workflow name' do
        let(:factory) { Gitlab::Config::Entry::Factory.new(described_class).value(workflow_hash) }

        context 'with a blank name' do
          let(:workflow_hash) do
            { name: '' }
          end

          it 'is invalid' do
            expect(config).not_to be_valid
          end

          it 'returns error about invalid name' do
            expect(config.errors).to include('workflow name is too short (minimum is 1 character)')
          end
        end

        context 'with too long name' do
          let(:workflow_hash) do
            { name: 'a' * 256 }
          end

          it 'is invalid' do
            expect(config).not_to be_valid
          end

          it 'returns error about invalid name' do
            expect(config.errors).to include('workflow name is too long (maximum is 255 characters)')
          end
        end

        context 'when name is nil' do
          let(:workflow_hash) { { name: nil } }

          it 'is valid' do
            expect(config).to be_valid
          end
        end

        context 'when name is not provided' do
          let(:workflow_hash) { { rules: [{ if: '$VAR' }] } }

          it 'is valid' do
            expect(config).to be_valid
          end
        end
      end
    end
  end

  describe '.default' do
    it 'is nil' do
      expect(described_class.default).to be_nil
    end
  end
end
