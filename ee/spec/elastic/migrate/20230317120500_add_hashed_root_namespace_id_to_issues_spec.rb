# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230317120500_add_hashed_root_namespace_id_to_issues.rb')

RSpec.describe AddHashedRootNamespaceIdToIssues, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230317120500
end
