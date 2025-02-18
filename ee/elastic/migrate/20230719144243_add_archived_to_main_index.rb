# frozen_string_literal: true

class AddArchivedToMainIndex < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  private

  def index_name
    ::Elastic::Latest::Config.index_name
  end

  def new_mappings
    {
      archived: {
        type: 'boolean'
      }
    }
  end
end

AddArchivedToMainIndex.prepend ::Elastic::MigrationObsolete
