# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240130154724_add_fields_to_projects_index.rb')

RSpec.describe AddFieldsToProjectsIndex, :elastic, feature_category: :global_search do
  let(:version) { 20240130154724 }

  include_examples 'migration adds mapping'
end
