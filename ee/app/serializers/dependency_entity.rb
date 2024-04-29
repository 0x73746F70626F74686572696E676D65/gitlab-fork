# frozen_string_literal: true

class DependencyEntity < Grape::Entity
  include RequestAwareEntity

  class AncestorEntity < Grape::Entity
    expose :name, :version

    def name
      object[:name] || object["name"]
    end

    def version
      object[:version] || object["version"]
    end
  end

  class LocationEntity < Grape::Entity
    expose :blob_path, :path, :top_level
    expose :ancestors, using: AncestorEntity
  end

  class VulnerabilityEntity < Grape::Entity
    expose :severity, :id

    expose :name do |vulnerability|
      if vulnerability.is_a?(::Vulnerability)
        vulnerability.title
      else
        vulnerability[:name]
      end
    end

    expose :url do |vulnerability, options|
      if vulnerability.is_a?(::Vulnerability)
        # Use options[:project] instead of vulnerability.project to avoid N+1 queries.
        # If options[:project] is nil, an error will be raised.
        ::Gitlab::Routing.url_helpers.project_security_vulnerability_url(options[:project], vulnerability)
      else
        vulnerability[:url]
      end
    end
  end

  class LicenseEntity < Grape::Entity
    expose :spdx_identifier, if: ->(_) { spdx_identifier? }
    expose :name, :url

    def spdx_identifier
      object[:spdx_identifier] || object["spdx_identifier"]
    end

    def name
      object[:name] || object["name"]
    end

    def url
      object[:url] || object["url"]
    end

    private

    def spdx_identifier?
      object.key?(:spdx_identifier) || object.key?("spdx_identifier")
    end
  end

  class ProjectEntity < Grape::Entity
    expose :full_path, :name
  end

  expose :name, :packager, :version
  expose :location, using: LocationEntity
  expose :vulnerabilities, using: VulnerabilityEntity, if: ->(_) { can_read_vulnerabilities? }
  expose :licenses, using: LicenseEntity, if: ->(_) { can_read_licenses? } do |object|
    object[:licenses].presence || [::Gitlab::LicenseScanning::PackageLicenses::UNKNOWN_LICENSE]
  end
  expose :occurrence_count, if: ->(_) { group? } do |object|
    object.respond_to?(:occurrence_count) ? object.occurrence_count : 1
  end
  expose :project, using: ProjectEntity, if: ->(_) { group? }
  expose :project_count, if: ->(_) { group? } do |object|
    object.respond_to?(:project_count) ? object.project_count : 1
  end
  expose :component_version_id, as: :component_id, if: ->(_) { group? }

  expose :id, as: :occurrence_id, if: ->(_) { group? || project_level_sbom_occurrences_enabled? }
  expose :vulnerability_count, if: ->(_) { group? || project_level_sbom_occurrences_enabled? }

  private

  def can_read_vulnerabilities?
    can?(request.user, :read_security_resource, request.try(:project)) && !project_level_sbom_occurrences_enabled?
  end

  def can_read_licenses?
    can?(request.user, :read_licenses, subject)
  end

  def group?
    request.try(:group).present?
  end

  def subject
    request.try(:project) || request.try(:group) || request.try(:organization)
  end

  def project_level_sbom_occurrences_enabled?
    project = request.try(:project)
    project.present? && Feature.enabled?(:project_level_sbom_occurrences, project)
  end
end
