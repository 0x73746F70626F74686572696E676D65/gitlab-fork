# frozen_string_literal: true

require 'spec_helper'
require_relative 'migration_shared_examples'
require File.expand_path('ee/elastic/migrate/20220118150500_delete_orphaned_commits.rb')

RSpec.describe DeleteOrphanedCommits, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20220118150500
end
