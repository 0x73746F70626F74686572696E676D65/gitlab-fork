# frozen_string_literal: true

class AddHashedRootNamespaceIdToIssues < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = Issue

  private

  def new_mappings
    {
      hashed_root_namespace_id: {
        type: 'integer'
      }
    }
  end
end

AddHashedRootNamespaceIdToIssues.prepend ::Elastic::MigrationObsolete
