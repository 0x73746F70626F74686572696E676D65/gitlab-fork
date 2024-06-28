# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230821123542_backfill_archived_field_in_blob.rb')

RSpec.describe BackfillArchivedFieldInBlob, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230821123542
end
