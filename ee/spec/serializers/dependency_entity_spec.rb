# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyEntity, feature_category: :dependency_management do
  describe '#as_json' do
    let_it_be(:user) { create(:user) }
    let(:project) { create(:project, :repository, :private) }
    let(:request) { double('request') }
    let(:dependency) { build(:dependency, :with_vulnerabilities, :with_licenses, :indirect) }
    let(:params) { { request: request } }

    subject { described_class.represent(dependency, params).as_json }

    before do
      allow(request).to receive(:project).and_return(project)
      allow(request).to receive(:user).and_return(user)
      stub_feature_flags(project_level_sbom_occurrences: false)
    end

    context 'when all required features available' do
      before do
        stub_licensed_features(security_dashboard: true, license_scanning: true)
        allow(request).to receive(:project).and_return(project)
        allow(request).to receive(:user).and_return(user)
      end

      context 'with developer' do
        before do
          project.add_developer(user)
        end

        it 'includes license info and vulnerabilities' do
          is_expected.to eq(dependency.except(:package_manager, :iid))
        end

        it 'does not include component_id' do
          expect(subject.keys).not_to include(:component_id)
        end

        context 'with project_level_sbom_occurrences enabled' do
          before do
            stub_feature_flags(project_level_sbom_occurrences: true)
          end

          it 'includes occurrence_id and vulnerability_count' do
            is_expected.to match(hash_including(:occurrence_id, :vulnerability_count))
          end

          it 'does not include vulnerabilities' do
            is_expected.not_to match(hash_including(:vulnerabilities))
          end

          context 'when include_vulnerabilities is set to true' do
            before do
              params.merge!({ include_vulnerabilities: true })
            end

            it 'does include vulnerabilities' do
              is_expected.to match(hash_including(:vulnerabilities))
            end
          end
        end
      end

      context 'with reporter' do
        before do
          project.add_reporter(user)
        end

        it 'includes license info and not vulnerabilities' do
          is_expected.to eq(dependency.except(:vulnerabilities, :package_manager, :iid))
        end
      end
    end

    context 'when all required features are unavailable' do
      before do
        project.add_developer(user)
      end

      it 'does not include licenses and vulnerabilities' do
        is_expected.to eq(dependency.except(:vulnerabilities, :licenses, :package_manager, :iid))
      end
    end

    context 'when there is no dependency path attributes' do
      let(:dependency) { build(:dependency, :with_vulnerabilities, :with_licenses) }

      it 'correctly represent location' do
        location = subject[:location]

        expect(location[:ancestors]).to be_nil
        expect(location[:top_level]).to be_nil
        expect(location[:path]).to eq('package_file.lock')
      end
    end

    context 'with an Sbom::Occurrence' do
      subject { described_class.represent(sbom_occurrence, request: request).as_json }

      let(:project) { create(:project, :repository, :private, :in_group) }
      let(:sbom_occurrence) { create(:sbom_occurrence, :mit, :bundler, :with_ancestors, project: project) }

      before do
        allow(request).to receive(:project).and_return(nil)
        allow(request).to receive(:group).and_return(project.group)

        stub_licensed_features(security_dashboard: true)
        project.group.add_developer(user)
      end

      it 'renders the proper representation' do
        expect(subject.as_json).to eq({
          "name" => sbom_occurrence.name,
          "occurrence_count" => 1,
          "packager" => sbom_occurrence.packager,
          "project_count" => 1,
          "version" => sbom_occurrence.version,
          "licenses" => sbom_occurrence.licenses,
          "component_id" => sbom_occurrence.component_version_id,
          "vulnerability_count" => 0,
          "occurrence_id" => sbom_occurrence.id
        })
      end

      context "when there are no known licenses" do
        let(:sbom_occurrence) { create(:sbom_occurrence, project: project) }

        it 'injects an unknown license' do
          expect(subject.as_json['licenses']).to match_array([
            "spdx_identifier" => "unknown",
            "name" => "unknown",
            "url" => nil
          ])
        end
      end
    end

    context 'with an organization' do
      let_it_be(:organization) { create(:organization, :default) }
      let_it_be(:project) { create(:project, organization: organization) }
      let_it_be(:dependency) { create(:sbom_occurrence, :mit, :bundler, project: project) }

      before do
        stub_licensed_features(security_dashboard: true, license_scanning: true)

        allow(request).to receive(:project).and_return(nil)
        allow(request).to receive(:group).and_return(nil)
        allow(request).to receive(:organization).and_return(organization)
      end

      it 'renders the proper representation' do
        expect(subject.keys).to match_array([
          :name, :packager, :version, :licenses, :location
        ])

        expect(subject[:name]).to eq(dependency.name)
        expect(subject[:packager]).to eq(dependency.packager)
        expect(subject[:version]).to eq(dependency.version)
      end

      it 'renders location' do
        expect(subject.dig(:location, :blob_path)).to eq(dependency.location[:blob_path])
        expect(subject.dig(:location, :path)).to eq(dependency.location[:path])
      end

      it 'renders each license' do
        dependency.licenses.each_with_index do |_license, index|
          expect(subject.dig(:licenses, index, :name)).to eq(dependency.licenses[index]['name'])
          expect(subject.dig(:licenses, index, :spdx_identifier)).to eq(
            dependency.licenses[index]['spdx_identifier']
          )
          expect(subject.dig(:licenses, index, :url)).to eq(dependency.licenses[index]['url'])
        end
      end
    end
  end
end
