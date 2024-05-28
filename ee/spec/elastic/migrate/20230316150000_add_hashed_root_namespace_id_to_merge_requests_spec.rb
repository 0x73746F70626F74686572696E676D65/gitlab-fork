# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230316150000_add_hashed_root_namespace_id_to_merge_requests.rb')

RSpec.describe AddHashedRootNamespaceIdToMergeRequests, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230316150000
end
