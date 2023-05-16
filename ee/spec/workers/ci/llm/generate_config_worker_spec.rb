# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Llm::GenerateConfigWorker, feature_category: :pipeline_composition do
  let_it_be(:ai_mesage) { create(:message, :ai) }

  let(:worker) { described_class.new }

  describe '#perform' do
    let(:ai_message_id) { ai_mesage.id }

    subject { worker.perform(ai_message_id) }

    it 'calls the generate config service' do
      service = instance_double(Ci::Llm::GenerateConfigService)

      expect(Ci::Llm::GenerateConfigService)
        .to receive(:new).with(ai_message: ai_mesage)
        .and_return(service)
      expect(service).to receive(:execute)

      subject
    end

    context 'when no ai message' do
      let(:ai_message_id) { non_existing_record_id }

      it { expect(subject).to eq nil }
    end
  end
end
