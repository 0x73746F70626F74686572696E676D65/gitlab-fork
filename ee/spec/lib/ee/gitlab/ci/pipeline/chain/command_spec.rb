# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::Command, feature_category: :continuous_integration do
  let_it_be(:project) { create(:project, :repository) }

  describe '#execution_policy_mode?', feature_category: :security_policy_management do
    subject { command.execution_policy_mode? }

    let(:command) { described_class.new(project: project, execution_policy_dry_run: execution_policy_dry_run) }
    let(:execution_policy_dry_run) { true }

    it { is_expected.to eq(true) }

    context 'when execution_policy_dry_run is nil' do
      let(:execution_policy_dry_run) { nil }

      it { is_expected.to eq(false) }
    end

    context 'when feature flag "pipeline_execution_policy_type" is disabled' do
      before do
        stub_feature_flags(pipeline_execution_policy_type: false)
      end

      it { is_expected.to eq(false) }
    end
  end
end
