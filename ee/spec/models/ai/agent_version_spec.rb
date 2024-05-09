# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AgentVersion, feature_category: :mlops do
  let_it_be(:base_project) { create(:project) }
  let_it_be(:agent) { create(:ai_agent, project: base_project) }
  let_it_be(:agent1) { create(:ai_agent, project: base_project) }
  let_it_be(:agent2) { create(:ai_agent, project: base_project) }

  let_it_be(:agent_version1) { create(:ai_agent_version, agent: agent1) }
  let_it_be(:agent_version2) { create(:ai_agent_version, agent: agent2) }
  let_it_be(:agent_version3) { create(:ai_agent_version, agent: agent1) }
  let_it_be(:agent_version4) { create(:ai_agent_version, agent: agent2) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:agent) }
    it { is_expected.to have_many(:files) }
    it { is_expected.to have_many(:attachments) }
  end

  describe 'validation' do
    subject { build(:ai_agent_version) }

    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:agent) }
    it { is_expected.to validate_presence_of(:prompt) }
    it { is_expected.to validate_length_of(:prompt).is_at_most(5000) }

    it { is_expected.to validate_presence_of(:model) }
    it { is_expected.to validate_length_of(:model).is_at_most(255) }
    it { is_expected.to be_valid }

    describe 'agent' do
      context 'when project is different' do
        subject(:errors) do
          mv = described_class.new(agent: agent, project: agent.project)
          mv.validate
          mv.errors
        end

        before do
          allow(agent).to receive(:project_id).and_return(non_existing_record_id)
        end

        it { expect(errors[:agent]).to include('agent project must be the same') }
      end
    end
  end

  describe '.order_by_agent_id_id_desc' do
    subject { described_class.order_by_agent_id_id_desc }

    it 'orders by (agent_id, id desc)' do
      is_expected.to match_array([agent_version3, agent_version1, agent_version4, agent_version2])
    end
  end

  describe '.latest_by_agent' do
    subject { described_class.latest_by_agent }

    it 'returns only the latest agent version per agent id' do
      is_expected.to match_array([agent_version4, agent_version3])
    end
  end
end
