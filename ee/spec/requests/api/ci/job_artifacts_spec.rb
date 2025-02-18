# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::JobArtifacts, feature_category: :build_artifacts do
  include HttpBasicAuthHelpers
  include DependencyProxyHelpers
  include Ci::JobTokenScopeHelpers
  include HttpIOHelpers

  let_it_be(:project, reload: true) do
    create(:project, :repository, :in_group, public_builds: false)
  end

  let_it_be(:pipeline, reload: true) do
    create(:ci_pipeline, project: project, sha: project.commit.id, ref: project.default_branch)
  end

  let(:user) { create(:user) }
  let(:api_user) { user }
  let(:guest) { create(:project_member, :guest, project: project).user }
  let!(:job) { create(:ci_build, :artifacts, pipeline: pipeline, project: project) }

  before do
    project.add_developer(user)
  end

  describe 'GET /projects/:id/jobs/:job_id/artifacts' do
    context 'with job artifacts' do
      context 'with audit events enabled', :aggregate_failures do
        before do
          project.group.root_ancestor.external_audit_event_destinations.create!(destination_url: 'http://example.com')
          stub_licensed_features(admin_audit_log: true, extended_audit_events: true, external_audit_events: true)
        end

        let(:job) { create(:ci_build, :artifacts, pipeline: pipeline, project: project) }

        subject(:request_artifact) { get api("/projects/#{project.id}/jobs/#{job.id}/artifacts", api_user) }

        it 'audits downloads' do
          expect(::Gitlab::Audit::Auditor).to(
            receive(:audit).with(hash_including(name: 'job_artifact_downloaded')).and_call_original
          )

          request_artifact
        end
      end
    end
  end
end
