# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::TaskSerializerService, feature_category: :global_search do
  let_it_be(:node) { create(:zoekt_node) }
  let_it_be(:task) { create(:zoekt_task, node: node) }

  let(:service) { described_class.new(task) }

  subject(:execute_task) { service.execute }

  describe '.execute' do
    it 'passes arguments to new and calls execute' do
      expect(described_class).to receive(:new).with(task).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(task)
    end
  end

  describe '#execute' do
    it 'serializes the task' do
      expect(execute_task[:name]).to eq(:index)
      expect(execute_task[:payload].keys).to contain_exactly(
        :GitalyConnectionInfo,
        :Callback,
        :RepoId,
        :FileSizeLimit,
        :Timeout
      )
    end

    context 'when local socket is used' do
      let(:connection_data) { { "address" => "unix:gdk-ee/praefect.socket", "token" => nil } }

      before do
        allow(Gitlab::GitalyClient).to receive(:connection_data).and_return(connection_data)
      end

      it 'transforms unix socket' do
        expected_path = "unix:#{Rails.root.join('gdk-ee/praefect.socket')}"
        expect(execute_task[:payload][:GitalyConnectionInfo][:Address]).to eq(expected_path)
      end
    end

    context 'with :force_index_repo task' do
      let(:task) { create(:zoekt_task, task_type: :force_index_repo) }

      it 'serializes the task' do
        expect(execute_task[:name]).to eq(:index)
        expect(execute_task[:payload].keys).to contain_exactly(
          :GitalyConnectionInfo,
          :Callback,
          :RepoId,
          :FileSizeLimit,
          :Timeout,
          :Force
        )
      end
    end

    context 'with :delete_repo task' do
      let(:task) { create(:zoekt_task, task_type: :delete_repo) }

      it 'serializes the task' do
        expect(execute_task[:name]).to eq(:delete)
        expect(execute_task[:payload].keys).to contain_exactly(:RepoId, :Callback)
        expect(execute_task[:payload][:RepoId]).to eq(task.project_identifier)
      end
    end

    context 'with unknown task' do
      let(:task) { create(:zoekt_task) }

      before do
        allow(task).to receive(:task_type).and_return(:unknown)
      end

      it 'raises an exception' do
        expect { execute_task }.to raise_error(ArgumentError)
      end
    end
  end
end
