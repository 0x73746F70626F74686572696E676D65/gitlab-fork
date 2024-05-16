# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230607500000_backfill_milestone_permissions_to_milestone_documents.rb')

RSpec.describe BackfillMilestonePermissionsToMilestoneDocuments, :elastic_delete_by_query, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230607500000
end
