# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::TrainingUrlsFinder do
  let_it_be(:project) { create(:project) }
  let_it_be(:langauge) { nil }
  let_it_be(:vulnerability) { create(:vulnerability, :with_findings, project: project) }
  let_it_be(:identifier) { create(:vulnerabilities_identifier, project: project, external_type: 'cwe', external_id: 2) }

  subject { described_class.new(project, identifier_external_ids, language).execute }

  context 'no identifier with cwe external type' do
    let(:identifier_external_ids) { [] }

    it 'returns empty list' do
      is_expected.to be_empty
    end
  end

  context 'identifiers with cwe external type' do
    let(:identifier_external_ids) { [identifier.external_id] }

    context 'when there is no training provider enabled for project' do
      it 'returns empty list' do
        is_expected.to be_empty
      end
    end

    context 'when there is training provider enabled for project' do
      let_it_be(:security_training_provider) { create(:security_training_provider, name: 'Kontra') }

      before do
        create(:security_training, :primary, project: project, provider: security_training_provider)
      end

      it 'calls Security::TrainingProviders::KontraUrlFinder#execute' do
        expect_next_instance_of(::Security::TrainingProviders::KontraUrlFinder) do |finder|
          expect(finder).to receive(:execute)
        end

        subject
      end

      context 'when training url has been reactively cached' do
        before do
          allow_next_instance_of(::Security::TrainingProviders::KontraUrlFinder) do |finder|
            allow(finder).to receive(:response_url).and_return(url: 'http://test.host/test')
          end
        end

        it 'returns training urls list with status completed' do
          is_expected.to match_array(
            [{ name: 'Kontra', url: 'http://test.host/test', status: 'completed', identifier: identifier.external_id }]
          )
        end

        context 'when a language is provided' do
          let_it_be(:langauge) { 'ruby' }

          it 'returns training urls list with status completed' do
            is_expected.to match_array(
              [{
                name: 'Kontra',
                url: 'http://test.host/test',
                status: 'completed',
                identifier: identifier.external_id
              }]
            )
          end
        end
      end

      context 'when training url has not yet been reactively cached' do
        before do
          allow_next_instance_of(::Security::TrainingProviders::KontraUrlFinder) do |finder|
            allow(finder).to receive(:response_url).and_return(nil)
          end
        end

        it 'returns training urls list with status pending' do
          is_expected.to match_array([{ name: 'Kontra', url: nil, status: 'pending' }])
        end

        context 'when a language is provided' do
          let_it_be(:langauge) { 'ruby' }

          it 'returns training urls list with status pending' do
            is_expected.to match_array([{ name: 'Kontra', url: nil, status: 'pending' }])
          end
        end
      end

      context 'when training urls finder returns nil url' do
        before do
          allow_next_instance_of(::Security::TrainingProviders::KontraUrlFinder) do |finder|
            allow(finder).to receive(:response_url).and_return(url: nil)
          end
        end

        it 'returns empty list when training urls finder returns nil' do
          is_expected.to be_empty
        end
      end

      context 'when sub class in not defined for provider' do
        before do
          security_training_provider.update_attribute(:name, "Notdefined")
        end

        it 'returns empty list' do
          is_expected.to be_empty
        end
      end
    end
  end
end
