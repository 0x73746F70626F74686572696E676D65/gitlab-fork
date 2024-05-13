# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230321091100_backfill_hashed_root_namespace_id_on_issues.rb')

RSpec.describe BackfillHashedRootNamespaceIdOnIssues, :elastic_delete_by_query, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230321091100
end
