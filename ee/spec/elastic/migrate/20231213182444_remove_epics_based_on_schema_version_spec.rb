# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20231213182444_remove_epics_based_on_schema_version.rb')

RSpec.describe RemoveEpicsBasedOnSchemaVersion, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20231213182444
end
