# frozen_string_literal: true

FactoryBot.define do
  factory :sbom_occurrence, class: 'Sbom::Occurrence' do
    pipeline { association :ci_pipeline }
    project { pipeline.project }
    commit_sha { pipeline.sha }
    component_version { association :sbom_component_version }
    component { component_version&.component || association(:sbom_component) }
    source { association :sbom_source, packager_name: packager_name }
    source_package { association :sbom_source_package }
    traversal_ids { project.namespace.traversal_ids }
    archived { project.archived }

    trait :os_occurrence do
      source do
        association :sbom_source, source_type: :container_scanning, packager_name: packager_name,
          operating_system: { 'name' => 'debian', 'version' => '9' }
      end
    end

    trait :registry_occurrence do
      source do
        association :sbom_source, source_type: :container_scanning_for_registry, packager_name: packager_name,
          operating_system: { 'name' => 'debian', 'version' => '9' }
      end
    end

    trait :with_vulnerabilities do
      vulnerability_count { 2 }
      vulnerabilities { build_list(:vulnerability, vulnerability_count) }
    end

    transient do
      packager_name { 'npm' }
    end

    trait :bundler do
      packager_name { 'bundler' }
    end

    trait :npm do
      packager_name { 'npm' }
    end

    trait :nuget do
      packager_name { 'nuget' }
    end

    trait :yarn do
      packager_name { 'yarn' }
    end

    trait :apache_2 do
      after(:build) do |occurrence|
        occurrence.licenses.push({
          'spdx_identifier' => 'Apache-2.0',
          'name' => 'Apache 2.0 License',
          'url' => 'https://spdx.org/licenses/Apache-2.0.html'
        })
      end
    end

    trait :mit do
      after(:build) do |occurrence|
        occurrence.licenses.push({
          'spdx_identifier' => 'MIT',
          'name' => 'MIT License',
          'url' => 'https://spdx.org/licenses/MIT.html'
        })
      end
    end

    trait :mpl_2 do
      after(:build) do |occurrence|
        occurrence.licenses.push({
          'spdx_identifier' => 'MPL-2.0',
          'name' => 'Mozilla Public License 2.0',
          'url' => 'https://spdx.org/licenses/MPL-2.0.html'
        })
      end
    end

    trait :with_ancestors do
      ancestors { [{ name: 'libc', version: '1.2.3' }] }
    end

    after(:build) do |occurrence|
      occurrence.uuid = Sbom::OccurrenceUUID.generate(
        project_id: occurrence.project.id,
        component_id: occurrence.component.id,
        component_version_id: occurrence.component_version&.id,
        source_id: occurrence.source&.id
      )

      occurrence.package_manager ||= occurrence.source&.source&.dig('package_manager', 'name')
      occurrence.input_file_path ||= occurrence.source&.source&.dig('input_file', 'path')
      occurrence.component_name ||= occurrence.component&.name
    end
  end
end
