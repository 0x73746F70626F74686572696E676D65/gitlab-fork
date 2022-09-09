# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::AssignPartition do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(project: project, current_user: user)
  end

  let(:pipeline) { build(:ci_pipeline, project: project) }
  let(:step) { described_class.new(pipeline, command) }
  let(:current_partition_id) { 123 }

  describe '#perform!' do
    before do
      stub_const("#{described_class}::DEFAULT_PARTITION_ID", current_partition_id)
    end

    subject { step.perform! }

    it 'assigns partition_id to pipeline' do
      expect { subject }.to change(pipeline, :partition_id).to(current_partition_id)
    end
  end
end
