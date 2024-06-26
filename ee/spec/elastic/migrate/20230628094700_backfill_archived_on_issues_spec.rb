# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230628094700_backfill_archived_on_issues.rb')

RSpec.describe BackfillArchivedOnIssues, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230628094700
end
