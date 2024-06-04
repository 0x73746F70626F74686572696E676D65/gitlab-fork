# frozen_string_literal: true

if $LOADED_FEATURES.include?(File.expand_path('../../../../spec/spec_helper.rb', __dir__.to_s))
  # return if spec_helper is already loaded, so we don't accidentally override any configuration in it
  return
end

if ENV['SPRING_TMP_PATH']
  warn "\n\n\nERROR: Spring is detected as running due to ENV['SPRING_TMP_PATH']=#{ENV['SPRING_TMP_PATH']} found.\n\n" \
       "Do not run #{__FILE__} with Spring enabled, it can cause Zeitwerk errors.\n\n" \
       "Exiting.\n\n"

  exit 1
end

require_relative '../../../../spec/fast_spec_helper'
require_relative '../../../../spec/support/matchers/result_matchers'
require_relative '../../../../spec/support/railway_oriented_programming'
require_relative '../../support/shared_contexts/remote_development/agent_info_status_fixture_not_implemented_error'
require_relative '../../support/shared_contexts/remote_development/remote_development_shared_contexts'

require 'rspec-parameterized'
require 'json_schemer'
require 'devfile'
require 'gitlab/rspec/next_instance_of'

RSpec.configure do |config|
  # Ensure that all specs which require this fast_spec_helper have the `:fast` tag at the top-level describe
  config.after(:suite) do
    RSpec.world.example_groups.each do |example_group|
      # Check only top-level describes
      next unless example_group.metadata[:parent_example_group].nil?

      unless example_group.metadata[:rd_fast]
        raise "Top-level describe blocks must have the `:rd_fast` tag when `rd_fast_spec_helper` is required. " \
              "It is missing on example group: #{example_group.description}"
      end
    end
  end

  # Set up rspec features required by the remote development specs
  config.include NextInstanceOf
  config.mock_with :rspec do |mocks|
    mocks.verify_doubled_constant_names = false
  end
end
