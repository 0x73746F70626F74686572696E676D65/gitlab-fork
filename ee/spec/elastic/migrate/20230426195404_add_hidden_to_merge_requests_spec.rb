# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230426195404_add_hidden_to_merge_requests.rb')

RSpec.describe AddHiddenToMergeRequests, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230426195404
end
