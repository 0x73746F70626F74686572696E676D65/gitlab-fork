# frozen_string_literal: true

class AddHiddenToMergeRequests < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = MergeRequest

  private

  def new_mappings
    {
      hidden: {
        type: 'boolean'
      }
    }
  end
end

AddHiddenToMergeRequests.prepend ::Elastic::MigrationObsolete
