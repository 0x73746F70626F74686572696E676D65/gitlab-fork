# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230731225441_reindex_work_items_to_fix_archived.rb')

RSpec.describe ReindexWorkItemsToFixArchived, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230731225441
end
