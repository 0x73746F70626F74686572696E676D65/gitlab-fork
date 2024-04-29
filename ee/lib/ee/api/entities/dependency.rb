# frozen_string_literal: true

module EE
  module API
    module Entities
      class Dependency < Grape::Entity
        expose :name, :version, :package_manager
        expose :dependency_file_path do |dependency|
          if dependency.is_a?(::Sbom::Occurrence)
            dependency.input_file_path
          else
            dependency[:location][:path]
          end
        end
        expose :vulnerabilities, using: DependencyEntity::VulnerabilityEntity, if: ->(_, opts) { can_read_vulnerabilities?(opts[:user], opts[:project]) }
        expose :licenses, using: DependencyEntity::LicenseEntity, if: ->(_, opts) { can_read_licenses?(opts[:user], opts[:project]) }

        private

        def can_read_vulnerabilities?(user, project)
          Ability.allowed?(user, :read_security_resource, project)
        end

        def can_read_licenses?(user, project)
          Ability.allowed?(user, :read_licenses, project)
        end
      end
    end
  end
end
