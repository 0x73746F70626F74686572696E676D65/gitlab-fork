# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::DeleteSourceBranchWorker do
  let_it_be(:merge_request) { create(:merge_request) }
  let_it_be(:user) { create(:user) }

  let(:sha) { merge_request.source_branch_sha }
  let(:worker) { described_class.new }

  describe '#perform' do
    context 'with a non-existing merge request' do
      it 'does nothing' do
        expect(::Branches::DeleteService).not_to receive(:new)
        expect(::MergeRequests::RetargetChainService).not_to receive(:new)

        worker.perform(non_existing_record_id, sha, user.id)
      end
    end

    context 'with a non-existing user' do
      it 'does nothing' do
        expect(::Branches::DeleteService).not_to receive(:new)
        expect(::MergeRequests::RetargetChainService).not_to receive(:new)

        worker.perform(merge_request.id, sha, non_existing_record_id)
      end
    end

    context 'with existing user and merge request' do
      it 'calls service to delete source branch' do
        expect_next_instance_of(::Branches::DeleteService) do |instance|
          expect(instance).to receive(:execute).with(merge_request.source_branch)
        end

        worker.perform(merge_request.id, sha, user.id)
      end

      it 'calls service to try retarget merge requests' do
        expect_next_instance_of(::MergeRequests::RetargetChainService) do |instance|
          expect(instance).to receive(:execute).with(merge_request)
        end

        worker.perform(merge_request.id, sha, user.id)
      end

      context 'source branch sha does not match' do
        it 'does nothing' do
          expect(::Branches::DeleteService).not_to receive(:new)
          expect(::MergeRequests::RetargetChainService).not_to receive(:new)

          worker.perform(merge_request.id, 'new-source-branch-sha', user.id)
        end
      end

      context 'when delete service returns an error' do
        let(:service_result) { ServiceResponse.error(message: 'placeholder') }

        it 'tracks the exception' do
          expect_next_instance_of(::Branches::DeleteService) do |instance|
            expect(instance).to receive(:execute).with(merge_request.source_branch).and_return(service_result)
          end

          expect(service_result).to receive(:track_exception).and_call_original

          worker.perform(merge_request.id, sha, user.id)
        end

        context 'when track_delete_source_errors is disabled' do
          before do
            stub_feature_flags(track_delete_source_errors: false)
          end

          it 'does not track the exception' do
            expect_next_instance_of(::Branches::DeleteService) do |instance|
              expect(instance).to receive(:execute).with(merge_request.source_branch).and_return(service_result)
            end

            expect(service_result).not_to receive(:track_exception)

            worker.perform(merge_request.id, sha, user.id)
          end
        end

        it 'still retargets the merge request' do
          expect_next_instance_of(::Branches::DeleteService) do |instance|
            expect(instance).to receive(:execute).with(merge_request.source_branch).and_return(service_result)
          end

          expect_next_instance_of(::MergeRequests::RetargetChainService) do |instance|
            expect(instance).to receive(:execute).with(merge_request)
          end

          worker.perform(merge_request.id, sha, user.id)
        end
      end
    end

    it_behaves_like 'an idempotent worker' do
      let(:merge_request) { create(:merge_request) }
      let(:job_args) { [merge_request.id, sha, user.id] }
    end
  end
end
