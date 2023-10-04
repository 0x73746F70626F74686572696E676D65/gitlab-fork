# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GithubImport::Importer::PullRequestImporter, :clean_gitlab_redis_cache, feature_category: :importers do
  let(:project) { create(:project, :repository) }
  let(:client) { double(:client) }
  let(:user) { create(:user) }
  let(:created_at) { Time.new(2017, 1, 1, 12, 00) }
  let(:updated_at) { Time.new(2017, 1, 1, 12, 15) }
  let(:merged_at) { Time.new(2017, 1, 1, 12, 17) }

  let(:source_commit) { project.repository.commit('feature') }
  let(:target_commit) { project.repository.commit('master') }
  let(:milestone) { create(:milestone, project: project) }
  let(:state) { :closed }

  let(:pull_request) do
    alice = Gitlab::GithubImport::Representation::User.new(id: 4, login: 'alice')

    Gitlab::GithubImport::Representation::PullRequest.new(
      iid: 42,
      title: 'My Pull Request',
      description: 'This is my pull request',
      source_branch: 'feature',
      source_branch_sha: source_commit.id,
      target_branch: 'master',
      target_branch_sha: target_commit.id,
      source_repository_id: 400,
      target_repository_id: 200,
      source_repository_owner: 'alice',
      state: state,
      milestone_number: milestone.iid,
      author: alice,
      assignee: alice,
      created_at: created_at,
      updated_at: updated_at,
      merged_at: state == :closed && merged_at
    )
  end

  let(:importer) { described_class.new(pull_request, project, client) }

  describe '#execute' do
    let(:mr) { double(:merge_request, id: 10, merged?: false) }

    it 'imports the pull request' do
      expect(importer)
        .to receive(:create_merge_request)
        .and_return([mr, false])

      expect(importer)
        .to receive(:set_merge_request_assignees)
        .with(mr)

      expect(importer)
        .to receive(:insert_git_data)
        .with(mr, false)

      expect_any_instance_of(Gitlab::GithubImport::IssuableFinder)
        .to receive(:cache_database_id)
        .with(mr.id)

      importer.execute
    end

    it 'caches the created MR ID even if importer later fails' do
      error = StandardError.new('mocked error')

      allow_next_instance_of(described_class) do |importer|
        allow(importer)
          .to receive(:create_merge_request)
          .and_return([mr, false])
        allow(importer)
          .to receive(:set_merge_request_assignees)
          .and_raise(error)
      end

      expect_next_instance_of(Gitlab::GithubImport::IssuableFinder) do |finder|
        expect(finder)
          .to receive(:cache_database_id)
          .with(mr.id)
      end

      expect { importer.execute }.to raise_error(error)
    end
  end

  describe '#create_merge_request' do
    before do
      allow(importer.milestone_finder)
        .to receive(:id_for)
        .with(pull_request)
        .and_return(milestone.id)
    end

    context 'when the author could be found' do
      before do
        allow(importer.user_finder)
          .to receive(:author_id_for)
          .with(pull_request)
          .and_return([user.id, true])
      end

      it 'imports the pull request with the pull request author as the merge request author' do
        expect(importer)
          .to receive(:insert_and_return_id)
          .with(
            {
              iid: 42,
              title: 'My Pull Request',
              description: 'This is my pull request',
              source_project_id: project.id,
              target_project_id: project.id,
              source_branch: 'github/fork/alice/feature',
              target_branch: 'master',
              state_id: 3,
              milestone_id: milestone.id,
              author_id: user.id,
              created_at: created_at,
              updated_at: updated_at
            },
            project.merge_requests
          )
          .and_call_original

        importer.create_merge_request
      end

      it 'returns the created merge request' do
        mr, exists = importer.create_merge_request

        expect(mr).to be_instance_of(MergeRequest)
        expect(exists).to eq(false)
      end

      context 'when the source and target branch are identical' do
        before do
          allow(pull_request).to receive_messages(
            source_repository_id: pull_request.target_repository_id,
            source_branch: 'master'
          )
        end

        it 'uses a generated source branch name for the merge request' do
          expect(importer)
            .to receive(:insert_and_return_id)
            .with(
              {
                iid: 42,
                title: 'My Pull Request',
                description: 'This is my pull request',
                source_project_id: project.id,
                target_project_id: project.id,
                source_branch: 'master-42',
                target_branch: 'master',
                state_id: 3,
                milestone_id: milestone.id,
                author_id: user.id,
                created_at: created_at,
                updated_at: updated_at
              },
              project.merge_requests
            )
            .and_call_original

          importer.create_merge_request
        end
      end

      context 'when the import fails due to a foreign key error' do
        it 'does not raise any errors' do
          expect(importer)
            .to receive(:insert_and_return_id)
            .and_raise(ActiveRecord::InvalidForeignKey, 'invalid foreign key')

          expect { importer.create_merge_request }.not_to raise_error
        end
      end

      context 'when the merge request already exists' do
        it 'returns the existing merge request' do
          mr1, exists1 = importer.create_merge_request
          mr2, exists2 = importer.create_merge_request

          expect(mr2).to eq(mr1)
          expect(exists1).to eq(false)
          expect(exists2).to eq(true)
        end
      end
    end

    context 'when the author could not be found' do
      before do
        allow(importer.user_finder)
          .to receive(:author_id_for)
          .with(pull_request)
          .and_return([project.creator_id, false])
      end

      it 'imports the pull request with the project creator as the merge request author' do
        expect(importer)
          .to receive(:insert_and_return_id)
          .with(
            {
              iid: 42,
              title: 'My Pull Request',
              description: "*Created by: alice*\n\nThis is my pull request",
              source_project_id: project.id,
              target_project_id: project.id,
              source_branch: 'github/fork/alice/feature',
              target_branch: 'master',
              state_id: 3,
              milestone_id: milestone.id,
              author_id: project.creator_id,
              created_at: created_at,
              updated_at: updated_at
            },
            project.merge_requests
          )
          .and_call_original

        importer.create_merge_request
      end
    end

    context 'when merge request is invalid' do
      before do
        allow(pull_request).to receive(:formatted_source_branch).and_return(nil)
        allow(importer.user_finder)
          .to receive(:author_id_for)
          .with(pull_request)
          .and_return([project.creator_id, false])
      end

      it 'fails validation' do
        expect { importer.create_merge_request }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '#set_merge_request_assignees' do
    let_it_be(:merge_request) { create(:merge_request) }

    before do
      allow(importer.user_finder)
        .to receive(:assignee_id_for)
        .with(pull_request)
        .and_return(user_id)

      importer.set_merge_request_assignees(merge_request)
    end

    context 'when pull request has an assignee' do
      let(:user_id) { user.id }

      it 'sets merge request assignees' do
        expect(merge_request.assignee_ids).to eq [user.id]
      end
    end

    context 'when pull request does not have any assignees' do
      let(:user_id) { nil }

      it 'does not set merge request assignees' do
        expect(merge_request.assignee_ids).to eq []
      end
    end
  end

  describe '#insert_git_data' do
    before do
      allow(importer.milestone_finder)
        .to receive(:id_for)
        .with(pull_request)
        .and_return(milestone.id)

      allow(importer.user_finder)
        .to receive(:author_id_for)
        .with(pull_request)
        .and_return([user.id, true])
    end

    it 'does not create the source branch if merge request is merged' do
      mr = insert_git_data

      expect(project.repository.branch_exists?(mr.source_branch)).to be_falsey
      expect(project.repository.branch_exists?(mr.target_branch)).to be_truthy
    end

    context 'when merge request is open' do
      let(:state) { :opened }

      it 'creates the source branch' do
        # Ensure the project creator is creating the branches because the
        # merge request author may not have access to push to this
        # repository. The project owner may also be a group.
        allow(project.repository).to receive(:add_branch).with(project.creator, anything, anything).and_call_original

        mr = insert_git_data

        expect(project.repository.branch_exists?(mr.source_branch)).to be_truthy
        expect(project.repository.branch_exists?(mr.target_branch)).to be_truthy
      end

      it 'is able to retry on pre-receive errors' do
        expect(importer).to receive(:insert_or_replace_git_data).twice.and_call_original
        expect(project.repository).to receive(:add_branch).and_raise('exception')

        expect { insert_git_data }.to raise_error('exception')

        expect(project.repository).to receive(:add_branch).with(project.creator, anything, anything).and_call_original

        mr = insert_git_data

        expect(project.repository.branch_exists?(mr.source_branch)).to be_truthy
        expect(project.repository.branch_exists?(mr.target_branch)).to be_truthy
        expect(mr.merge_request_diffs).to be_one
      end

      it 'ignores Git command errors when creating a branch' do
        expect(project.repository).to receive(:add_branch).and_raise(Gitlab::Git::CommandError)
        expect(Gitlab::ErrorTracking).to receive(:track_exception).and_call_original

        mr = insert_git_data

        expect(project.repository.branch_exists?(mr.source_branch)).to be_falsey
        expect(project.repository.branch_exists?(mr.target_branch)).to be_truthy
      end

      it 'ignores Git PreReceive errors when creating a branch' do
        expect(project.repository).to receive(:add_branch).and_raise(Gitlab::Git::PreReceiveError)
        expect(Gitlab::ErrorTracking).to receive(:track_exception).and_call_original

        mr = insert_git_data

        expect(project.repository.branch_exists?(mr.source_branch)).to be_falsey
        expect(project.repository.branch_exists?(mr.target_branch)).to be_truthy
      end
    end

    it 'creates a merge request diff and sets it as the latest' do
      mr = insert_git_data

      expect(mr.merge_request_diffs.exists?).to eq(true)
      expect(mr.reload.latest_merge_request_diff_id).to eq(mr.merge_request_diffs.first.id)
    end

    it 'creates the merge request diff commits' do
      mr = insert_git_data

      diff = mr.merge_request_diffs.reload.first

      expect(diff.merge_request_diff_commits.exists?).to eq(true)
    end

    context 'when the merge request exists' do
      it 'creates the merge request diffs if they do not yet exist' do
        mr, _ = importer.create_merge_request

        mr.merge_request_diffs.delete_all

        importer.insert_git_data(mr, true)

        expect(mr.merge_request_diffs.exists?).to eq(true)
      end
    end

    def insert_git_data
      mr, exists = importer.create_merge_request
      importer.insert_git_data(mr, exists)
      mr
    end
  end
end
