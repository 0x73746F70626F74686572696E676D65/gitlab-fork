# frozen_string_literal: true

# Worker for storing security reports into the database.
#
# DEPRECATED: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/151541
class StoreSecurityReportsWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker
  include SecurityScansQueue
  include Gitlab::ExclusiveLeaseHelpers

  LEASE_TTL = 30.minutes.freeze

  data_consistency :always
  sidekiq_options retry: 3
  feature_category :vulnerability_management
  worker_resource_boundary :cpu

  def perform(pipeline_id)
    pipeline = Ci::Pipeline.find_by_id(pipeline_id)

    return unless pipeline&.project&.can_store_security_reports?

    in_lock(lease_key(pipeline.project), ttl: LEASE_TTL) do
      ::Security::Ingestion::IngestReportsService.execute(pipeline)
    end
  end

  private

  def lease_key(project)
    "StoreSecurityReportsWorker:projects:#{project.id}"
  end
end
