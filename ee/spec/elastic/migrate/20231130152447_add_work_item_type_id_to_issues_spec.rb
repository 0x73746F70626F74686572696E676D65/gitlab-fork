# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20231130152447_add_work_item_type_id_to_issues.rb')

RSpec.describe AddWorkItemTypeIdToIssues, :elastic, feature_category: :global_search do
  let(:version) { 20231130152447 }

  include_examples 'migration adds mapping'
end
