# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Xray::StoreDependenciesService, feature_category: :code_suggestions do
  let_it_be(:project) { create(:project) }
  let(:language) { 'Ruby' }
  let(:dependencies) { %w[rails devise attr_encrypted grape kaminari] }
  let(:scanner_version) { '2.0.0' }
  let(:dependencies_hash) { dependencies.map { |name| { "name" => name } } }

  describe '#execute' do
    subject(:execute) { described_class.new(project, language, dependencies, scanner_version).execute }

    context 'when there is no report for programming language yet' do
      it 'responds with success' do
        is_expected.to be_success
      end

      it 'creates new XrayReport' do
        expect { execute }.to change { project.xray_reports.count }.by(1)
      end

      it 'creates a report with correct data', :aggregate_failures do
        execute

        report = project.xray_reports.last!

        expect(report.lang).to eq(language)
        expect(report.file_checksum).to be_present
        expect(report.payload['checksum']).to be_present
        expect(report.payload['scannerVersion']).to eq(scanner_version)
        expect(report.payload['libs']).to match_array(dependencies_hash)
      end
    end

    context 'when there is a report for this programming language already' do
      let_it_be_with_reload(:report_for_ruby) { create(:xray_report, project: project, lang: 'Ruby') }

      it 'responds with success' do
        is_expected.to be_success
      end

      it 'does not create new XrayReport' do
        expect { execute }.not_to change { project.xray_reports.count }
      end

      it 'updates an existing report' do
        expect do
          execute
          report_for_ruby.reload
        end.to change { report_for_ruby.payload['libs'] }.to eq(dependencies_hash)
      end
    end

    context 'when project is blank' do
      let(:project) { nil }

      it 'responds with error', :aggregate_failures do
        result = execute

        expect(result).to be_error
        expect(result.message).to eq('project cannot be blank')
      end
    end

    context 'when language is blank' do
      let(:language) { '' }

      it 'responds with error', :aggregate_failures do
        result = execute

        expect(result).to be_error
        expect(result.message).to eq('language cannot be blank')
      end
    end
  end
end
