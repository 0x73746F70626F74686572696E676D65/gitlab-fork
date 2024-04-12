# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "groups/security/compliance_dashboards/show", type: :view, feature_category: :compliance_management do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:group) { build_stubbed(:group, namespace_settings: build_stubbed(:namespace_settings)) }
  let(:project_framework_csv_export_path) do
    group_security_compliance_project_framework_reports_path(group, format: :csv)
  end

  let(:violations_csv_export_path) { group_security_compliance_violation_reports_path(group, format: :csv) }
  let(:adherences_csv_export_path) { group_security_compliance_standards_adherence_reports_path(group, format: :csv) }
  let(:frameworks_csv_export_path) { group_security_compliance_framework_reports_path(group, format: :csv) }
  let(:merge_commits_csv_export_path) { group_security_merge_commit_reports_path(group) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:group, group)
  end

  it 'renders with the correct data attributes', :aggregate_failures do
    render

    expect(rendered).to have_selector('#js-compliance-report')
    expect(rendered).to have_selector("[data-can-add-edit='true']")
    expect(rendered)
      .to have_selector("[data-project-frameworks-csv-export-path='#{project_framework_csv_export_path}']")
    expect(rendered).to have_selector("[data-violations-csv-export-path='#{violations_csv_export_path}']")
    expect(rendered).to have_selector("[data-merge-commits-csv-export-path='#{merge_commits_csv_export_path}']")
    expect(rendered).to have_selector("[data-group-path='#{group.full_path}']")
    expect(rendered).to have_selector("[data-root-ancestor-path='#{group.root_ancestor.full_path}']")
    expect(rendered).to have_selector("[data-base-path='#{group_security_compliance_dashboard_path(group)}']")
    expect(rendered).to have_selector("[data-pipeline-configuration-enabled='false']")
  end

  context 'for violations export' do
    it 'renders with the correct data attributes', :aggregate_failures do
      render

      expect(rendered).to have_selector("[data-violations-csv-export-path='#{violations_csv_export_path}']")
    end
  end

  context 'for adherences export', :aggregate_failures do
    it 'renders with the correct data attributes' do
      render

      expect(rendered).to have_selector("[data-adherences-csv-export-path='#{adherences_csv_export_path}']")
    end
  end

  context 'for frameworks export', :aggregate_failures do
    context "when feature `compliance_frameworks_report_csv_export` is enabled" do
      it 'renders with the correct data attributes' do
        render

        expect(rendered).to have_selector("[data-frameworks-csv-export-path='#{frameworks_csv_export_path}']")
      end
    end

    context "when feature `compliance_frameworks_report_csv_export` is not enabled" do
      before do
        stub_feature_flags(compliance_frameworks_report_csv_export: false)
      end

      it 'renders with the correct data attributes' do
        render

        expect(rendered).not_to have_selector("[data-frameworks-csv-export-path='#{frameworks_csv_export_path}']")
      end
    end
  end
end
