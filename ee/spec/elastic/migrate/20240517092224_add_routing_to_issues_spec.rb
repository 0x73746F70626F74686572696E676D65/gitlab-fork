# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240517092224_add_routing_to_issues.rb')

RSpec.describe AddRoutingToIssues, feature_category: :global_search do
  let(:version) { 20240517092224 }

  describe 'migration', :elastic, :sidekiq_inline do
    include_examples 'migration adds mapping'
  end
end
