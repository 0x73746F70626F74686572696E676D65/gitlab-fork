# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230717132609_backfill_archived_on_work_items.rb')

RSpec.describe BackfillArchivedOnWorkItems, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230717132609
end
