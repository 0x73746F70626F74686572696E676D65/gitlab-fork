# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240208160152_add_count_fields_to_projects.rb')

RSpec.describe AddCountFieldsToProjects, :elastic, feature_category: :global_search do
  let(:version) { 20240208160152 }

  include_examples 'migration adds mapping'
end
