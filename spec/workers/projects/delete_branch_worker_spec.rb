# frozen_string_literal: true
# rubocop: disable Gitlab/ServiceResponse

require 'spec_helper'

RSpec.describe Projects::DeleteBranchWorker, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let(:branch) { 'master' }
  let(:worker) { described_class.new }
  let(:service_result) { ServiceResponse.success(message: 'placeholder', http_status: 200) }

  before do
    allow_next_instance_of(::Branches::DeleteService) do |instance|
      allow(instance).to receive(:execute).with(branch).and_return(service_result)
    end
  end

  describe '#perform' do
    context 'when the branch does not exist' do
      let(:branch) { 'non_existent_branch_name' }

      it 'does nothing' do
        expect(::Branches::DeleteService).not_to receive(:new)

        worker.perform(project.id, user.id, branch)
      end
    end

    context 'with a non-existing project' do
      it 'does nothing' do
        expect(::Branches::DeleteService).not_to receive(:new)

        worker.perform(non_existing_record_id, user.id, branch)
      end
    end

    context 'with a non-existing user' do
      it 'does nothing' do
        expect(::Branches::DeleteService).not_to receive(:new)

        worker.perform(project.id, non_existing_record_id, branch)
      end
    end

    context 'with existing user and project' do
      it 'calls service to delete source branch' do
        expect_next_instance_of(::Branches::DeleteService) do |instance|
          expect(instance).to receive(:execute).with(branch).and_return(service_result)
        end

        worker.perform(project.id, user.id, branch)
      end

      context 'when delete service returns an error' do
        let(:service_result) { ServiceResponse.error(message: 'placeholder', http_status: status_code) }

        context 'when the status code is 400' do
          let(:status_code) { 400 }

          it 'tracks and raises the exception' do
            expect_next_instance_of(::Branches::DeleteService) do |instance|
              expect(instance).to receive(:execute).with(branch).and_return(service_result)
            end

            expect(service_result).to receive(:track_and_raise_exception).and_call_original

            expect { worker.perform(project.id, user.id, branch) }.to raise_error(StandardError)
          end
        end

        context 'when the status code is not 400' do
          let(:status_code) { 405 }

          it 'does not track the exception' do
            expect_next_instance_of(::Branches::DeleteService) do |instance|
              expect(instance).to receive(:execute).with(branch).and_return(service_result)
            end

            expect(service_result).not_to receive(:track_and_raise_exception)

            expect { worker.perform(project.id, user.id, branch) }.not_to raise_error
          end
        end

        context 'when track_and_raise_delete_source_errors is disabled' do
          let(:status_code) { 400 }

          before do
            stub_feature_flags(track_and_raise_delete_source_errors: false)
          end

          it 'does not track the exception' do
            expect_next_instance_of(::Branches::DeleteService) do |instance|
              expect(instance).to receive(:execute).with(branch).and_return(service_result)
            end

            expect(service_result).not_to receive(:track_and_raise_exception)

            expect { worker.perform(project.id, user.id, branch) }.not_to raise_error
          end
        end
      end
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [project.id, user.id, branch] }
    end
  end
  # rubocop: enable Gitlab/ServiceResponse
end
