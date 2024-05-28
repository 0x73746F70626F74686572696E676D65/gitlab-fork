# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230427555555_backfill_hidden_on_merge_requests.rb')

RSpec.describe BackfillHiddenOnMergeRequests, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230427555555
end
