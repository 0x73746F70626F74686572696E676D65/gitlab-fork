# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230702000000_backfill_existing_group_wiki.rb')

RSpec.describe BackfillExistingGroupWiki, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230702000000
end
