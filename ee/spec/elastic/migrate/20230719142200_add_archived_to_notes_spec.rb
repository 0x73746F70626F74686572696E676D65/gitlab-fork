# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230719142200_add_archived_to_notes.rb')

RSpec.describe AddArchivedToNotes, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230719142200
end
