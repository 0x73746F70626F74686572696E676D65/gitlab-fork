# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230307102400_backfill_hashed_root_namespace_id_on_notes.rb')

RSpec.describe BackfillHashedRootNamespaceIdOnNotes, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230307102400
end
