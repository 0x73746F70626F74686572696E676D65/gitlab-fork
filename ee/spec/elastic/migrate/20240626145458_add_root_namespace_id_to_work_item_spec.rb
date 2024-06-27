# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240626145458_add_root_namespace_id_to_work_item.rb')

RSpec.describe AddRootNamespaceIdToWorkItem, :elastic, feature_category: :global_search do
  let(:version) { 20240626145458 }

  include_examples 'migration adds mapping'
end
