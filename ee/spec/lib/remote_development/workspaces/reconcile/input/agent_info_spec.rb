# frozen_string_literal: true

require_relative '../../../rd_fast_spec_helper'

RSpec.describe RemoteDevelopment::Workspaces::Reconcile::Input::AgentInfo, :rd_fast, feature_category: :remote_development do
  let(:agent_info_constructor_args) do
    {
      name: 'name',
      namespace: 'namespace',
      actual_state: ::RemoteDevelopment::Workspaces::States::RUNNING,
      deployment_resource_version: '1'
    }
  end

  let(:other) { described_class.new(**agent_info_constructor_args) }

  subject(:agent_info_instance) do
    described_class.new(**agent_info_constructor_args)
  end

  describe '#==' do
    context 'when objects are equal' do
      it 'returns true' do
        expect(agent_info_instance).to eq(other)
      end
    end

    context 'when objects are not equal' do
      it 'returns false' do
        other.instance_variable_set(:@name, 'other_name')
        expect(agent_info_instance).not_to eq(other)
      end
    end
  end
end
