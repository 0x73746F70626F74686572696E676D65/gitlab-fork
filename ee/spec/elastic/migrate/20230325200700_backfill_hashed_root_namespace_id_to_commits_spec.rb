# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230325200700_backfill_hashed_root_namespace_id_to_commits.rb')

RSpec.describe BackfillHashedRootNamespaceIdToCommits, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230325200700
end
