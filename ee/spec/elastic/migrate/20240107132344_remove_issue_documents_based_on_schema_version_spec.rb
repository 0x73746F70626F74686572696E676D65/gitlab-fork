# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240107132344_remove_issue_documents_based_on_schema_version.rb')

RSpec.describe RemoveIssueDocumentsBasedOnSchemaVersion, :elastic, :sidekiq_inline, feature_category: :global_search do
  include_examples 'migration deletes documents based on schema version',
    quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/446204' do
    let(:version) { 20240107132344 }
    let(:objects) { create_list(:issue, 3) }
    let(:expected_throttle_delay) { 1.minute }
    let(:expected_batch_size) { 10000 }
  end
end
