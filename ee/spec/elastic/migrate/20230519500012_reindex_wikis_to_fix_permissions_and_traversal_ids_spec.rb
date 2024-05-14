# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230519500012_reindex_wikis_to_fix_permissions_and_traversal_ids.rb')

RSpec.describe ReindexWikisToFixPermissionsAndTraversalIds, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230519500012
end
