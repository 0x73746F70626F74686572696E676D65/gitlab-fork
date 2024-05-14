# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexingTaskService, feature_category: :global_search do
  let_it_be(:ns) { create(:namespace) }
  let_it_be(:project) { create(:project, :repository, namespace: ns) }
  let_it_be(:node) { create(:zoekt_node, :enough_free_space) }
  let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: ns) }
  let_it_be(:zoekt_index) { create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, node: node) }

  describe '.execute' do
    let(:service) { described_class.new(project, :index_repo) }

    it 'executes the task' do
      expect(described_class).to receive(:new).with(project.id, :index_repo).and_return(service)
      expect(service).to receive(:execute)
      described_class.execute(project.id, :index_repo)
    end
  end

  describe '#execute' do
    context 'when FF zoekt_create_indexing_tasks is disabled' do
      let(:service) { described_class.new(project, :index_repo) }

      before do
        stub_feature_flags(zoekt_create_indexing_tasks: false)
      end

      it 'does not creates and Search::Zoekt::Task record' do
        expect { service.execute }.not_to change { Search::Zoekt::Task.count }
      end
    end

    context 'when task_type is delete_repo' do
      let(:service) { described_class.new(project, :delete_repo) }

      it 'creates Search::Zoekt::Task record' do
        expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
      end
    end

    context 'when task_type is not delete_repo' do
      let(:task_type) { 'index_repo' }
      let(:service) { described_class.new(project, task_type) }

      context 'for preflight_check? is false' do
        context 'if project does not have a repository' do
          let_it_be(:project) { create(:project) }

          it 'does not creates Search::Zoekt::Task record' do
            expect { service.execute }.not_to change { Search::Zoekt::Task.count }
          end
        end

        context 'if project has an empty repo' do
          let_it_be(:project) { create(:project, :empty_repo) }

          it 'does not creates Search::Zoekt::Task record' do
            expect { service.execute }.not_to change { Search::Zoekt::Task.count }
          end
        end

        context 'if project does not exists' do
          let_it_be(:project) { create(:project, :empty_repo) }

          it 'does not creates Search::Zoekt::Task record' do
            service = described_class.new(project, task_type)
            project.destroy!
            expect { service.execute }.not_to change { Search::Zoekt::Task.count }
          end
        end
      end

      context 'when Repository does not exists' do
        it 'creates a Repository record and a Task record' do
          expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
            .and change { Search::Zoekt::Repository.count }.by(1)
          repo = Search::Zoekt::Repository.find_by(project: project, zoekt_index: zoekt_index)
          expect(repo).to be_present
          new_task = repo.tasks.last
          expect(new_task.zoekt_node_id).to eq zoekt_index.zoekt_node_id
          expect(new_task).to be_pending
          expect(new_task.task_type).to eq task_type
        end
      end

      context 'when Repository already exists' do
        let_it_be(:zoekt_repo) { create(:zoekt_repository, project: project, zoekt_index: zoekt_index) }

        it 'creates only a Task record' do
          expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
            .and change { Search::Zoekt::Repository.count }.by(0)
          new_task = zoekt_repo.tasks.last
          expect(new_task.zoekt_node_id).to eq zoekt_index.zoekt_node_id
          expect(new_task).to be_pending
          expect(new_task.task_type).to eq task_type
        end
      end

      context 'when delay is passed' do
        let(:delay) { 1.hour }
        let(:service) { described_class.new(project, task_type, delay: delay) }

        it 'sets perform_at with delay' do
          freeze_time do
            service.execute
            new_task = Search::Zoekt::Task.last
            expect(new_task.perform_at).to eq delay.from_now
          end
        end
      end
    end
  end
end
