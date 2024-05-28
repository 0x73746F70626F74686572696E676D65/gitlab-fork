# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230405500000_backfill_wiki_permissions_in_main_index.rb')

RSpec.describe BackfillWikiPermissionsInMainIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230405500000
end
