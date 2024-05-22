# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20230726094700_remove_projects_from_main_index.rb')

RSpec.describe RemoveProjectsFromMainIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20230726094700
end
