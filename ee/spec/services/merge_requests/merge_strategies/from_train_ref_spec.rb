# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::MergeStrategies::FromTrainRef, feature_category: :merge_trains do
  let_it_be(:user) { create(:user) }
  let_it_be(:user2) { create(:user) }

  let(:merge_request) { create(:merge_request, :simple, author: user2, assignees: [user2], squash: squash_on_merge) }
  let(:squash_on_merge) { false }
  let(:project) { merge_request.project }
  let!(:merge_train_car) { create(:merge_train_car, merge_request: merge_request, target_project: project) }
  let(:mergeable) { true }

  subject(:strategy) { described_class.new(merge_request, user) }

  before do
    allow(merge_request).to receive(:mergeable?).and_return(mergeable)
    project.add_maintainer(user)
  end

  describe '#validate!' do
    context 'when source is missing' do
      let!(:merge_train_car) { nil }

      it 'raises source error when source is missing' do
        error_message = 'No source for merge'

        expect { strategy.validate! }
          .to raise_exception(MergeRequests::MergeStrategies::StrategyError, error_message)
      end
    end

    context 'when merge request should be squashed but is not' do
      before do
        merge_request.target_project.project_setting.squash_always!
        merge_request.update!(squash: false)
      end

      it 'raises squashing error' do
        error_message = 'This project requires squashing commits when merge requests are accepted.'

        expect { strategy.validate! }
          .to raise_exception(MergeRequests::MergeStrategies::StrategyError, error_message)
      end
    end

    context 'when the merge train ref has changed in the meantime' do
      before do
        allow(project.repository).to(
          receive(:commit)
            .with(merge_request.train_ref_path)
            .and_return(instance_double(Gitlab::Git::Commit, sha: nil))
        )
      end

      it 'raises outdated merge source error' do
        error_message = 'Merge source out-of-date.'

        expect { strategy.validate! }
          .to raise_exception(MergeRequests::MergeStrategies::StrategyError, error_message)
      end
    end

    context 'when merge request is not mergeable' do
      let(:mergeable) { false }

      it 'raises mergability error' do
        error_message = 'Merge request is not mergeable'

        expect { strategy.validate! }
          .to raise_exception(MergeRequests::MergeStrategies::StrategyError, error_message)
      end
    end
  end

  describe '#execute_git_merge!' do
    subject(:result) { strategy.execute_git_merge! }

    it 'performs a fast-forward merge', :aggregate_failures do
      expect(merge_request.target_project.repository).to receive(:ff_merge).and_call_original
      expect(result[:commit_sha]).to eq(project.commit(merge_request.target_branch).sha)
    end

    describe 'result by merge method' do
      before do
        project.merge_method = merge_method
        project.save!
      end

      context 'when there is a merge commit' do
        where(:merge_method) { [:merge, :rebase_merge] }

        with_them do
          it 'has commit_sha and merge_commit_sha', :aggregate_failures do
            expect(result[:commit_sha]).to eq(project.commit(merge_request.target_branch).sha)
            expect(result[:squash_commit_sha]).to be_nil
            expect(result[:merge_commit_sha]).to eq(result[:commit_sha])
          end

          context 'when squashed' do
            let(:squash_on_merge) { true }

            it 'has commit_sha, squash_commit_sha and merge_commit_sha', :aggregate_failures do
              result

              target_branch_commit = project.commit(merge_request.target_branch)

              expect(result[:commit_sha]).to eq(target_branch_commit.sha)
              expect(result[:squash_commit_sha]).to eq(target_branch_commit.parents[1].sha)
              expect(result[:merge_commit_sha]).to eq(result[:commit_sha])
            end
          end
        end
      end

      context 'when fast-forward only' do
        let(:merge_method) { :ff }

        it 'has commit_sha', :aggregate_failures do
          expect(result[:commit_sha]).to eq(project.commit(merge_request.target_branch).sha)
          expect(result[:squash_commit_sha]).to be_nil
          expect(result[:merge_commit_sha]).to be_nil
        end

        context 'when squashed' do
          let(:squash_on_merge) { true }

          it 'has commit_sha and squash_commit_sha', :aggregate_failures do
            expect(result[:commit_sha]).to eq(project.commit(merge_request.target_branch).sha)
            expect(result[:squash_commit_sha]).to eq(result[:commit_sha])
            expect(result[:merge_commit_sha]).to be_nil
          end
        end
      end
    end
  end
end
