# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230518064300_backfill_project_permissions_in_blobs.rb')

RSpec.describe BackfillProjectPermissionsInBlobs, :elastic_clean, :sidekiq_inline,
  feature_category: :global_search do
    it_behaves_like 'a deprecated Advanced Search migration', 20230518064300
  end
