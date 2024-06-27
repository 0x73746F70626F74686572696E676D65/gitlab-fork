# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230703112233_reindex_commits_to_fix_permissions.rb')

RSpec.describe ReindexCommitsToFixPermissions, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230703112233
end
