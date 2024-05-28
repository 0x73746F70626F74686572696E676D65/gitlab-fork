# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230428500000_add_suffix_project_in_wiki_rid.rb')

RSpec.describe AddSuffixProjectInWikiRid, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230428500000
end
