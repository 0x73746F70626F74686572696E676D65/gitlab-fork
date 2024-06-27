# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230711140500_backfill_archived_on_merge_requests.rb')

RSpec.describe BackfillArchivedOnMergeRequests, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230711140500
end
