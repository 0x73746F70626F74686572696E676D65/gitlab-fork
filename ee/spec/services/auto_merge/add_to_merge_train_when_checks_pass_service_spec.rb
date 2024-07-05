# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AutoMerge::AddToMergeTrainWhenChecksPassService, feature_category: :code_review_workflow do
  let_it_be(:project, reload: true) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let(:service) { described_class.new(project, user) }

  let(:merge_request) do
    create(:merge_request, :with_merge_request_pipeline,
      source_project: project, source_branch: 'feature',
      target_project: project, target_branch: 'master')
  end

  let(:pipeline) { merge_request.reload.all_pipelines.first }

  before do
    project.add_maintainer(user)
    project.update!(merge_pipelines_enabled: true, merge_trains_enabled: true)
    stub_licensed_features(merge_trains: true, merge_pipelines: true)
    allow(AutoMergeProcessWorker).to receive(:perform_async).and_return(nil)
    merge_request.update_head_pipeline
  end

  describe '#execute' do
    subject(:execute) { service.execute(merge_request) }

    it 'enables auto merge' do
      expect(SystemNoteService)
        .to receive(:add_to_merge_train_when_checks_pass)
        .with(merge_request, project, user, merge_request.diff_head_pipeline.sha)

      execute

      expect(merge_request).to be_auto_merge_enabled
    end
  end

  describe '#process' do
    subject(:process) { service.process(merge_request) }

    before do
      service.execute(merge_request)
    end

    context 'when the merge request has ci enabled' do
      context 'when the latest pipeline in the merge request has succeeded' do
        before do
          pipeline.succeed!
        end

        context 'when its mergeable' do
          it 'executes MergeTrainService' do
            expect_next_instance_of(AutoMerge::MergeTrainService) do |train_service|
              expect(train_service).to receive(:execute).with(merge_request)
            end

            process
          end

          context 'when merge train strategy is not available for the merge request' do
            before do
              train_service = double
              allow(train_service).to receive(:available_for?).and_return(false)
              allow(AutoMerge::MergeTrainService).to receive(:new) { train_service }
            end

            it 'aborts auto merge' do
              expect(service).to receive(:abort).once.and_call_original

              expect(SystemNoteService)
                .to receive(:abort_add_to_merge_train_when_checks_pass).once
                .with(merge_request, project, user, 'This merge request cannot be added to the merge train')

              process
            end
          end
        end

        context 'when its not mergeable' do
          context 'when the MR is unchecked' do
            it 'executes MergeTrainService' do
              merge_request.mark_as_unchecked!

              expect_next_instance_of(AutoMerge::MergeTrainService) do |train_service|
                expect(train_service).to receive(:execute).with(merge_request)
              end

              process
            end
          end

          it 'does not initialize MergeTrainService' do
            merge_request.update!(title: merge_request.draft_title)
            expect(AutoMerge::MergeTrainService).not_to receive(:new)

            process
          end
        end
      end

      context 'when the latest pipeline has not succeeded' do
        it 'does not initialize MergeTrainService' do
          expect(AutoMerge::MergeTrainService).not_to receive(:new)

          process
        end
      end
    end

    context 'when the merge request does not have ci enabled' do
      it 'does not initialize MergeTrainService' do
        expect(AutoMerge::MergeTrainService).not_to receive(:new)

        process
      end
    end
  end

  describe '#cancel' do
    subject(:cancel) { service.cancel(merge_request) }

    let(:merge_request) { create(:merge_request, :add_to_merge_train_when_checks_pass, merge_user: user) }

    it 'cancels auto merge' do
      expect(SystemNoteService)
        .to receive(:cancel_add_to_merge_train_when_checks_pass)
        .with(merge_request, project, user)

      cancel

      expect(merge_request).not_to be_auto_merge_enabled
    end
  end

  describe '#abort' do
    subject(:abort_call) { service.abort(merge_request, 'an error') }

    let(:merge_request) { create(:merge_request, :add_to_merge_train_when_checks_pass, merge_user: user) }

    it 'aborts auto merge' do
      expect(SystemNoteService)
        .to receive(:abort_add_to_merge_train_when_checks_pass)
        .with(merge_request, project, user, 'an error')

      abort_call

      expect(merge_request).not_to be_auto_merge_enabled
    end
  end

  describe '#available_for?' do
    subject(:available_for) { service.available_for?(merge_request) }

    it { is_expected.to eq(true) }

    context 'when merge trains option is disabled' do
      before do
        allow(merge_request.project).to receive(:merge_trains_enabled?).and_return(false)
      end

      it { is_expected.to eq(false) }
    end

    context 'when merge_when_checks_pass_merge_train is false' do
      before do
        stub_feature_flags(merge_when_checks_pass_merge_train: false)
      end

      it { is_expected.to eq(false) }
    end

    context 'when the MR does not have ci enabled' do
      before do
        allow(merge_request).to receive(:has_ci_enabled?).and_return(false)
      end

      it { is_expected.to eq(false) }
    end

    context 'when merge request is not mergeable' do
      before do
        merge_request.update!(title: merge_request.draft_title)
      end

      it { is_expected.to eq(true) }
    end

    context 'when the user does not have permission to merge' do
      before do
        allow(merge_request).to receive(:can_be_merged_by?).and_return(false)
      end

      it { is_expected.to eq(false) }
    end
  end
end
