# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230908161822_reindex_work_item_to_fix_label_ids.rb')

RSpec.describe ReindexWorkItemToFixLabelIds, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230908161822
end
