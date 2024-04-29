# frozen_string_literal: true

class AddHashedRootNamespaceIdToMergeRequests < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = MergeRequest

  private

  def new_mappings
    {
      hashed_root_namespace_id: {
        type: 'integer'
      }
    }
  end
end

AddHashedRootNamespaceIdToMergeRequests.prepend ::Elastic::MigrationObsolete
