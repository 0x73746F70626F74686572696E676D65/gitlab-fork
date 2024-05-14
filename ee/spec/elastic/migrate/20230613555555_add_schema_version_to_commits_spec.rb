# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230613555555_add_schema_version_to_commits.rb')

RSpec.describe AddSchemaVersionToCommits, :elastic, :sidekiq_inline, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230613555555
end
