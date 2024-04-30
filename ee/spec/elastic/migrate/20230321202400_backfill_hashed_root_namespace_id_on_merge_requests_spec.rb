# frozen_string_literal: true

require 'spec_helper'
require_relative 'migration_shared_examples'
require File.expand_path('ee/elastic/migrate/20230321202400_backfill_hashed_root_namespace_id_on_merge_requests.rb')

RSpec.describe BackfillHashedRootNamespaceIdOnMergeRequests, :elastic_delete_by_query, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230321202400
end
