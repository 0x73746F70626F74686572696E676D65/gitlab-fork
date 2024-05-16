# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230503064300_backfill_project_permissions_in_blobs_using_permutations.rb') # rubocop disable Layout/LineLength

RSpec.describe BackfillProjectPermissionsInBlobsUsingPermutations, :elastic, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230503064300
end
