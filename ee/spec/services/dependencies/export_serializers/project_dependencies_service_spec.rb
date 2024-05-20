# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dependencies::ExportSerializers::ProjectDependenciesService, feature_category: :dependency_management do
  describe '.execute' do
    let(:dependency_list_export) { instance_double(Dependencies::DependencyListExport) }

    subject(:execute) { described_class.execute(dependency_list_export) }

    it 'instantiates a service object and sends execute message to it' do
      expect_next_instance_of(described_class, dependency_list_export) do |service_object|
        expect(service_object).to receive(:execute)
      end

      execute
    end
  end

  describe '#execute' do
    let_it_be(:author) { create(:user) }
    let_it_be(:project) { create(:project, :public, developers: [author]) }
    let_it_be(:dependency_list_export) { create(:dependency_list_export, project: project, author: author) }

    let(:service_class) { described_class.new(dependency_list_export) }

    subject(:dependencies) { service_class.execute.as_json[:dependencies] }

    before do
      stub_licensed_features(dependency_scanning: true, license_scanning: true, security_dashboard: true)
    end

    context 'when the project does not have dependencies' do
      it { is_expected.to be_empty }
    end

    context 'when project has dependencies' do
      let_it_be(:occurrences) { create_list(:sbom_occurrence, 2, :with_vulnerabilities, :mit, project: project) }

      def json_dependency(occurrence)
        vulnerabilities = occurrence.vulnerabilities.map do |vulnerability|
          {
            'id' => vulnerability.id,
            'name' => vulnerability.title,
            'severity' => vulnerability.severity,
            'url' => end_with("/security/vulnerabilities/#{vulnerability.id}")
          }
        end

        {
          'name' => occurrence.name,
          'packager' => occurrence.packager,
          'version' => occurrence.version,
          'occurrence_id' => occurrence.id,
          'location' => {
            'blob_path' =>
              "/#{project.full_path}/-/blob/#{occurrence.commit_sha}/#{occurrence.input_file_path}",
            'path' => occurrence.input_file_path,
            'top_level' => false,
            'ancestors' => occurrence.ancestors
          },
          'licenses' => occurrence.licenses,
          'vulnerabilities' => vulnerabilities,
          'vulnerability_count' => 2
        }
      end

      it 'returns expected dependencies' do
        expected_dependencies = occurrences.map { |occurrence| json_dependency(occurrence) }

        expect(dependencies.as_json).to match_array(expected_dependencies)
      end

      it 'does not have N+1 queries', :request_store do
        def render
          entity = described_class.new(dependency_list_export).execute
          Gitlab::Json.dump(entity)
        end

        control = ::ActiveRecord::QueryRecorder.new { render }

        create(:sbom_occurrence, :with_vulnerabilities, :mit, project: project)

        expect { render }.not_to exceed_query_limit(control)
      end
    end
  end
end
