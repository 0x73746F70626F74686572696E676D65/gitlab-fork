# frozen_string_literal: true

module CodeSuggestions
  module Xray
    class StoreDependenciesService
      def initialize(project, language, dependencies, scanner_version)
        @project = project
        @language = language
        @dependencies = dependencies
        @scanner_version = scanner_version
      end

      def execute
        return ServiceResponse.error(message: 'project cannot be blank') if project.blank?
        return ServiceResponse.error(message: 'language cannot be blank') if language.blank?

        checksum = Digest::SHA256.hexdigest(dependencies.join(' '))
        payload = {
          "scannerVersion" => scanner_version,
          "checksum" => checksum,
          "libs" => dependencies.map { |name| { "name" => name } }
        }

        Projects::XrayReport.upsert(
          { project_id: project.id, payload: payload, lang: language, file_checksum: checksum },
          unique_by: [:project_id, :lang]
        )

        ServiceResponse.success
      end

      private

      attr_reader :project, :language, :dependencies, :scanner_version
    end
  end
end
