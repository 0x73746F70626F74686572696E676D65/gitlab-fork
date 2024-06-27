# frozen_string_literal: true

class AddArchivedToIssues < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = Issue

  private

  def new_mappings
    {
      archived: {
        type: 'boolean'
      }
    }
  end
end

AddArchivedToIssues.prepend ::Elastic::MigrationObsolete
