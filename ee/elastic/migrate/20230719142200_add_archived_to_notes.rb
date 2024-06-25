# frozen_string_literal: true

class AddArchivedToNotes < Elastic::Migration
  include Elastic::MigrationUpdateMappingsHelper

  DOCUMENT_TYPE = Note

  private

  def new_mappings
    { archived: { type: 'boolean' } }
  end
end

AddArchivedToNotes.prepend ::Elastic::MigrationObsolete
