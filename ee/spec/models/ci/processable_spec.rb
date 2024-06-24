# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Processable, feature_category: :continuous_integration do
  describe 'delegations' do
    subject { described_class.new }

    it { is_expected.to delegate_method(:merge_train_pipeline?).to(:pipeline) }
  end

  describe '#set_execution_policy_job!' do
    shared_examples_for 'execution_policy_job! for processable' do
      it 'sets correct options' do
        expect { processable.set_execution_policy_job! }.to change { processable.options }
                                                      .to match(a_hash_including(execution_policy_job: true))
      end
    end

    context 'with ci_build' do
      let(:processable) { build(:ci_build) }

      it_behaves_like 'execution_policy_job! for processable'
    end

    context 'with ci_bridge' do
      let(:processable) { build(:ci_processable) }

      it_behaves_like 'execution_policy_job! for processable'
    end
  end

  describe '#execution_policy_job?' do
    subject { processable.execution_policy_job? }

    shared_examples_for 'execution_policy_job? for processable' do
      it { is_expected.to eq(false) }

      context 'when job is set as a policy job' do
        before do
          processable.set_execution_policy_job!
        end

        it { is_expected.to eq(true) }
      end
    end

    context 'with ci_build' do
      let(:processable) { build(:ci_build) }

      it_behaves_like 'execution_policy_job? for processable'
    end

    context 'with ci_bridge' do
      let(:processable) { build(:ci_bridge) }

      it_behaves_like 'execution_policy_job? for processable'
    end
  end
end
