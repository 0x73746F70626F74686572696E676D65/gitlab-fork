# frozen_string_literal: true

module Projects
  module Packages
    class InfrastructureRegistryController < Projects::ApplicationController
      include PackagesAccess

      feature_category :infrastructure_as_code

      def show
        @package = project.packages.find(params[:id])
        @package_files = if Feature.enabled?(:packages_installable_package_files, default_enabled: :yaml)
                           @package.installable_package_files.recent
                         else
                           @package.package_files.recent
                         end
      end
    end
  end
end
