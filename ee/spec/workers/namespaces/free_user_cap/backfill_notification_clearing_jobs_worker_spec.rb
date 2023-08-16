# frozen_string_literal: true

require 'spec_helper'

# Interim feature category experimentation_activation used here while waiting for
# https://gitlab.com/gitlab-com/www-gitlab-com/-/merge_requests/113300 to merge
RSpec.describe Namespaces::FreeUserCap::BackfillNotificationClearingJobsWorker,
  type: :worker,
  feature_category: :measurement_and_locking do
  let(:worker) { described_class.new }

  describe '#perform' do
    it 'does not add NotificationClearingWorker jobs to the limited capacity worker pool' do
      expect(Namespaces::FreeUserCap::NotificationClearingWorker).not_to receive(:perform_with_capacity)

      worker.perform
    end
  end
end
