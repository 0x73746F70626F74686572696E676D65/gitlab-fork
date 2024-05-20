# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillFindingInitialPipelineId, feature_category: :vulnerability_management, schema: 20240514030609 do
  subject(:perform_migration) { described_class.new(**args).perform }

  let(:args) do
    {
      start_id: vulnerability_findings.first.id,
      end_id: vulnerability_findings.last.id,
      batch_table: :vulnerability_occurrences,
      batch_column: :id,
      sub_batch_size: total_findings_count,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    }
  end

  let(:projects) { table(:projects) }
  let(:namespaces) { table(:namespaces) }
  let(:scanners) { table(:vulnerability_scanners) }
  let(:vulnerability_identifiers) { table(:vulnerability_identifiers) }
  let(:vulnerability_findings) { table(:vulnerability_occurrences) }
  let(:vulnerability_finding_pipelines) { table(:vulnerability_occurrence_pipelines) }

  let(:group_namespace) { namespaces.create!(name: 'gitlab-org', path: 'gitlab-org', type: 'Group') }
  let(:project) { create_project('gitlab', group_namespace) }

  let!(:finding1) do
    create_finding.tap do |finding|
      create_finding_pipeline!(finding_id: finding.id, pipeline_id: 1) # initial
      create_finding_pipeline!(finding_id: finding.id, pipeline_id: 2)
      create_finding_pipeline!(finding_id: finding.id, pipeline_id: 3) # latest
    end
  end

  let!(:finding2) do
    create_finding.tap do |finding|
      create_finding_pipeline!(finding_id: finding.id, pipeline_id: 4) # initial and latest
    end
  end

  # no pipeline as a sanity check to make sure nothing blows up
  let!(:finding3) { create_finding }
  let!(:finding4) do
    create_finding(initial_pipeline_id: 5, latest_pipeline_id: 5).tap do |finding|
      # initial_pipeline_id is already set to 5, so it should
      # not update to 555
      create_finding_pipeline!(finding_id: finding.id, pipeline_id: 555)
    end
  end

  let(:total_findings_count) { vulnerability_findings.all.count }

  it 'backfills initial_pipeline_id and latest_pipeline_id', :aggregate_failures do
    # .to(1) because finding3 has no pipeline
    expect { perform_migration }.to change {
      vulnerability_findings.where(initial_pipeline_id: nil).count
    }.from(3).to(1).and change { vulnerability_findings.where(initial_pipeline_id: nil).count }.from(3).to(1)

    expect(finding1.reload.initial_pipeline_id).to eq(1)
    expect(finding2.reload.initial_pipeline_id).to eq(4)
    expect(finding3.reload.initial_pipeline_id).to be_nil
    expect(finding4.reload.initial_pipeline_id).to eq(5)

    expect(finding1.latest_pipeline_id).to eq(3)
    expect(finding2.latest_pipeline_id).to eq(4)
    expect(finding3.latest_pipeline_id).to be_nil
    expect(finding4.latest_pipeline_id).to eq(5)
  end

  it 'does not have N+1 queries' do
    def run_migration(end_id: vulnerability_findings.last.id)
      described_class.new(**args.merge(end_id: end_id)).perform
    end

    control = ::ActiveRecord::QueryRecorder.new { run_migration }

    # reset backfilled rows to nil
    vulnerability_findings.update_all(initial_pipeline_id: nil, latest_pipeline_id: nil)
    create_finding.tap do |finding|
      create_finding_pipeline!(finding_id: finding.id, pipeline_id: 91)
    end

    expect { run_migration }.not_to exceed_query_limit(control)
  end

  context 'when a sub-batch only contains findings without an associated pipeline' do
    # finding3 has no pipeline associated with it
    let(:args) { super().merge(start_id: finding3.id, end_id: finding3.id) }

    it 'does not raise an error' do
      expect { perform_migration }.not_to raise_error
    end
  end

  def create_finding(initial_pipeline_id: nil, latest_pipeline_id: nil)
    scanner = scanners.find_or_create_by!(name: 'bar') do |scanner|
      scanner.project_id = project.id
      scanner.external_id = 'foo'
    end

    identifier = vulnerability_identifiers.create!(
      project_id: project.id,
      external_id: "CVE-2018-1234",
      external_type: "CVE",
      name: "CVE-2018-1234",
      fingerprint: SecureRandom.hex(20)
    )

    vulnerability_findings.create!(
      project_id: project.id,
      scanner_id: scanner.id,
      severity: 5, # medium
      confidence: 2, # unknown,
      report_type: 99, # generic
      primary_identifier_id: identifier.id,
      project_fingerprint: SecureRandom.hex(20),
      location_fingerprint: SecureRandom.hex(20),
      uuid: SecureRandom.uuid,
      name: "CVE-2018-1234",
      raw_metadata: "{}",
      metadata_version: "test:1.0",
      initial_pipeline_id: initial_pipeline_id,
      latest_pipeline_id: latest_pipeline_id
    )
  end

  def create_finding_pipeline!(finding_id:, pipeline_id:)
    vulnerability_finding_pipelines.create!(pipeline_id: pipeline_id, occurrence_id: finding_id)
  end

  def create_project(name, group)
    project_namespace = namespaces.create!(
      name: name,
      path: name,
      type: 'Project'
    )

    projects.create!(
      namespace_id: group.id,
      project_namespace_id: project_namespace.id,
      name: name,
      path: name,
      archived: false
    )
  end
end
