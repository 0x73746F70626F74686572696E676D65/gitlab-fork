# frozen_string_literal: true

class AddCiCatalogToProject < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = Project

  private

  def new_mappings
    {
      readme_content: {
        type: 'text'
      },
      ci_catalog: {
        type: 'boolean'
      }
    }
  end
end

AddCiCatalogToProject.prepend ::Elastic::MigrationObsolete
