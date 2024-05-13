# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230415500000_migrate_wikis_to_separate_index.rb')

RSpec.describe MigrateWikisToSeparateIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230415500000
end
