# frozen_string_literal: true

require Rails.root.join("spec/support/helpers/stub_requests.rb")

Dir[Rails.root.join("ee/spec/support/helpers/*.rb")].each { |f| require f }
Dir[Rails.root.join("ee/spec/support/shared_contexts/*.rb")].each { |f| require f }
Dir[Rails.root.join("ee/spec/support/shared_examples/*.rb")].each { |f| require f }
Dir[Rails.root.join("ee/spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.include EE::LicenseHelpers

  include StubSaasFeatures

  config.define_derived_metadata(file_path: %r{ee/spec/}) do |metadata|
    # For now, we assign a starter license for ee/spec
    metadata[:with_license] = metadata.fetch(:with_license, true)

    location = metadata[:location]
    metadata[:geo] = metadata.fetch(:geo, true) if location =~ %r{[/_]geo[/_]}
  end

  config.define_derived_metadata do |metadata|
    # There's already a value, so do not set a default
    next if metadata.has_key?(:without_license)
    # There's already an opposing value, so do not set a default
    next if metadata.has_key?(:with_license)

    metadata[:without_license] = true
  end

  config.before(:context, :with_license) do
    License.destroy_all # rubocop: disable Cop/DestroyAll
    TestLicense.init
  end

  config.after(:context, :with_license) do
    License.destroy_all # rubocop: disable Cop/DestroyAll
  end

  config.before(:context, :without_license) do
    License.destroy_all # rubocop: disable Cop/DestroyAll
  end

  config.after(:context, :without_license) do
    TestLicense.init
  end

  config.around(:example, :with_cloud_connector) do |example|
    create(:cloud_connector_access)
    CloudConnector::AvailableServices.clear_memoization(:access_data_reader)
    CloudConnector::AvailableServices.clear_memoization(:available_services)

    example.run

    CloudConnector::AvailableServices.clear_memoization(:access_data_reader)
    CloudConnector::AvailableServices.clear_memoization(:available_services)
  end

  config.around(:each, :geo_tracking_db) do |example|
    example.run if Gitlab::Geo.geo_database_configured?
  end

  config.define_derived_metadata do |metadata|
    metadata[:do_not_stub_snowplow_by_default] = true if metadata.has_key?(:snowplow_micro)
  end

  config.before(:example, :snowplow_micro) do
    config.include(Matchers::Snowplow)

    next unless Gitlab::Tracking.micro_verification_enabled?

    Matchers::Snowplow.clean_snowplow_queue

    stub_application_setting(snowplow_enabled: true)
    stub_application_setting(snowplow_app_id: 'gitlab-test')
  end
end
