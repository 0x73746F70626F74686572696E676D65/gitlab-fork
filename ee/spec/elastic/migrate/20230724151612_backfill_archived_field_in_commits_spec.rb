# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230724151612_backfill_archived_field_in_commits.rb')

RSpec.describe BackfillArchivedFieldInCommits, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230724151612
end
