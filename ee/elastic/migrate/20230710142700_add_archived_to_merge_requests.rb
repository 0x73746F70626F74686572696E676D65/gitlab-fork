# frozen_string_literal: true

class AddArchivedToMergeRequests < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = MergeRequest

  private

  def new_mappings
    {
      archived: {
        type: 'boolean'
      }
    }
  end
end

AddArchivedToMergeRequests.prepend ::Elastic::MigrationObsolete
