# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Repository, feature_category: :global_search do
  subject { create(:zoekt_repository) }

  describe 'relations' do
    it { is_expected.to belong_to(:zoekt_index).inverse_of(:zoekt_repositories) }
    it { is_expected.to belong_to(:project).inverse_of(:zoekt_repository) }
  end

  describe 'before_validation' do
    let_it_be(:zoekt_repo) { create(:zoekt_repository) }

    it 'sets project_identifier equal to project_id' do
      zoekt_repo.project_identifier = nil
      expect { zoekt_repo.valid? }.to change { zoekt_repo.project_identifier }.from(nil).to(zoekt_repo.project_id)
    end
  end

  describe 'validation' do
    let_it_be_with_reload(:zoekt_repo) { create(:zoekt_repository) }
    let(:zoekt_index) { zoekt_repo.zoekt_index }
    let(:project) { zoekt_repo.project }

    it 'validates project_id and project_identifier' do
      expect { zoekt_repo.project_id = nil }.not_to change { zoekt_repo.valid? }
      expect { zoekt_repo.project_id = zoekt_repo.project_identifier.next }.to change { zoekt_repo.valid? }.to false
    end

    it 'validated uniqueness on zoekt_index_id and project_identifier' do
      expect(zoekt_repo).to be_valid
      zoekt_repo2 = build(:zoekt_repository, project: nil, project_identifier: project.id, zoekt_index: zoekt_index)
      expect(zoekt_repo2).to be_invalid
    end
  end

  describe 'scope' do
    describe '.non_ready' do
      let_it_be(:zoekt_repository) { create(:zoekt_repository) }

      it 'returns non ready records' do
        create(:zoekt_repository, state: :ready)
        expect(described_class.non_ready).to contain_exactly zoekt_repository
      end
    end
  end

  describe '.create_tasks' do
    let(:task_type) { :index_repo }

    context 'when repository does not exists for a project and zoekt_index' do
      let_it_be(:project) { create(:project) }
      let_it_be(:index) { create(:zoekt_index) }

      it 'creates a new repository and task' do
        freeze_time do
          perform_at = Time.zone.now
          expect do
            described_class.create_tasks(project_id: project.id, zoekt_index: index, task_type: task_type,
              perform_at: perform_at
            )
          end.to change { described_class.count }.by(1).and change { Search::Zoekt::Task.count }.by(1)
          repo = Search::Zoekt::Repository.last
          expect(repo.project).to eq project
          expect(repo.zoekt_index).to eq index
          task = Search::Zoekt::Task.last
          expect(task.zoekt_repository).to eq repo
          expect(task.project_identifier).to eq repo.project_identifier
          expect(task).to be_index_repo
          expect(task.perform_at).to eq perform_at
        end
      end
    end

    context 'when repository already exists for a project and zoekt_index' do
      let_it_be(:repo) { create(:zoekt_repository) }
      let_it_be(:zoekt_index) { repo.zoekt_index }

      it 'creates task' do
        freeze_time do
          perform_at = Time.zone.now
          expect do
            described_class.create_tasks(project_id: repo.project_identifier, zoekt_index: zoekt_index,
              task_type: task_type, perform_at: perform_at
            )
          end.to change { described_class.count }.by(0).and change { Search::Zoekt::Task.count }.by(1)
          task = Search::Zoekt::Task.last
          expect(task.zoekt_repository).to eq repo
          expect(task.project_identifier).to eq repo.project_identifier
          expect(task).to be_index_repo
          expect(task.perform_at).to eq perform_at
        end
      end

      context 'when project is already deleted' do
        let_it_be(:repo_with_deleted_project) {  create(:zoekt_repository, zoekt_index: zoekt_index) }
        let_it_be(:repo_with_deleted_project2) { create(:zoekt_repository, zoekt_index: zoekt_index) }

        before do
          [repo_with_deleted_project.project, repo_with_deleted_project2.project].map(&:destroy!)
        end

        it 'creates task with the supplied project_id' do
          freeze_time do
            perform_at = Time.zone.now
            expect do
              described_class.create_tasks(project_id: repo_with_deleted_project2.project_identifier,
                zoekt_index: zoekt_index, task_type: :delete_repo, perform_at: perform_at
              )
            end.to change { described_class.count }.by(0).and change { Search::Zoekt::Task.count }.by(1)
            task = Search::Zoekt::Task.last
            expect(task.zoekt_repository).to eq repo_with_deleted_project2
            expect(task.project_identifier).to eq repo_with_deleted_project2.project_identifier
            expect(task).to be_delete_repo
            expect(task.perform_at).to eq perform_at
          end
        end
      end
    end
  end
end
