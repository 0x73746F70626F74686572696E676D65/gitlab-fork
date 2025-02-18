# frozen_string_literal: true

class AddArchivedToCommits < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  private

  def index_name
    ::Elastic::Latest::CommitConfig.index_name
  end

  def new_mappings
    {
      archived: {
        type: 'boolean'
      }
    }
  end
end

AddArchivedToCommits.prepend ::Elastic::MigrationObsolete
