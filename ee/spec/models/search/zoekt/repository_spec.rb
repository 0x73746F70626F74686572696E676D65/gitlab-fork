# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Repository, feature_category: :global_search do
  subject { create(:zoekt_repository) }

  describe 'relations' do
    it { is_expected.to belong_to(:zoekt_index).inverse_of(:zoekt_repositories) }
    it { is_expected.to belong_to(:project).inverse_of(:zoekt_repository) }
  end

  describe 'before_validation' do
    let(:zoekt_repository) { create(:zoekt_repository) }

    it 'sets project_identifier equal to project_id' do
      zoekt_repo = create(:zoekt_repository, project_identifier: "")
      zoekt_repo.valid?
      expect(zoekt_repo.project_identifier).to eq zoekt_repo.project_id
    end
  end

  describe 'validation' do
    let(:zoekt_repository) { create(:zoekt_repository) }

    it 'validates project_id and project_identifier' do
      expect { zoekt_repository.project_id = 'invalid_id' }.to change { zoekt_repository.valid? }.to false
    end

    it 'validated uniqueness on zoekt_index_id and project_id' do
      project = create(:project)
      zoekt_index = create(:zoekt_index)
      zoekt_repo = create(:zoekt_repository, project: project, zoekt_index: zoekt_index)
      expect(zoekt_repo.valid?).to be_truthy
      zoekt_repo1 = build(:zoekt_repository, project: project, zoekt_index: zoekt_index)

      expect(zoekt_repo1.valid?).to be_falsey
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
            described_class.create_tasks(project: project, zoekt_index: index, task_type: task_type,
              perform_at: perform_at)
          end.to change { described_class.count }.by(1).and change { Search::Zoekt::Task.count }.by(1)
          repo = index.zoekt_repositories.last
          expect(repo.project).to eq project
          expect(repo.zoekt_index).to eq index
          task = repo.tasks.last
          expect(task).to be_index_repo
          expect(task.perform_at).to eq perform_at
        end
      end
    end

    context 'when repository already exists for a project and zoekt_index' do
      let_it_be(:repo) { create(:zoekt_repository) }

      it 'creates task' do
        freeze_time do
          perform_at = Time.zone.now
          expect do
            described_class.create_tasks(project: repo.project, zoekt_index: repo.zoekt_index, task_type: task_type,
              perform_at: perform_at)
          end.to change { described_class.count }.by(0).and change { Search::Zoekt::Task.count }.by(1)
          task = repo.tasks.last
          expect(task).to be_index_repo
          expect(task.perform_at).to eq perform_at
        end
      end
    end
  end
end
