# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230530500000_migrate_projects_to_separate_index.rb')

RSpec.describe MigrateProjectsToSeparateIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230530500000
end
