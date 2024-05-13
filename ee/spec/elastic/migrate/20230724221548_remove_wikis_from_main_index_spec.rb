# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230724221548_remove_wikis_from_main_index.rb')

RSpec.describe RemoveWikisFromMainIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230724221548
end
