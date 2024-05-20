# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::SyncArchivedStatusService, feature_category: :dependency_management do
  let_it_be(:project) { create(:project, :archived) }
  let_it_be(:sbom_occurrence) { create(:sbom_occurrence, archived: false, project: project) }
  let_it_be(:sbom_occurrence_2) { create(:sbom_occurrence, archived: false, project: project) }

  let(:project_id) { project.id }

  subject(:sync) { described_class.new(project_id).execute }

  it 'updates sbom_occurrences.archived' do
    expect { sync }.to change { sbom_occurrence.reload.archived }.from(false).to(true)
      .and change { sbom_occurrence_2.reload.archived }.from(false).to(true)
  end

  context 'when project does not exist with id' do
    let(:project_id) { non_existing_record_id }

    it 'does not raise' do
      expect { sync }.not_to raise_error
    end
  end

  context 'when lease is taken' do
    include ExclusiveLeaseHelpers

    let_it_be(:other_project) { create(:project) }

    let(:lease_key) { "sync_sbom_occurrences_archived:projects:#{project_id}" }
    let(:lease_ttl) { 1.hour }

    before do
      stub_exclusive_lease_taken(lease_key, timeout: lease_ttl)
    end

    it 'does not permit parallel execution on the same project' do
      expect { sync }.to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
                          .and not_change { sbom_occurrence.reload.archived }
    end

    it 'allows parallel execution on different projects' do
      expect { described_class.new(other_project.id).execute }.not_to raise_error
    end
  end
end
