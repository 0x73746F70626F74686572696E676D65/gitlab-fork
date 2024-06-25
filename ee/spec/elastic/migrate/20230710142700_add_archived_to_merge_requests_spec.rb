# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230710142700_add_archived_to_merge_requests.rb')

RSpec.describe AddArchivedToMergeRequests, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230710142700
end
