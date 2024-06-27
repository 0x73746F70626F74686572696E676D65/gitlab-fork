# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230628094243_add_archived_to_issues.rb')

RSpec.describe AddArchivedToIssues, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230628094243
end
