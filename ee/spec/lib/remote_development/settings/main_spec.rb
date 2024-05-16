# frozen_string_literal: true

require_relative '../rd_fast_spec_helper'

RSpec.describe RemoteDevelopment::Settings::Main, :rd_fast, feature_category: :remote_development do
  include RemoteDevelopment::RailwayOrientedProgrammingHelpers

  let(:input_value) { { some_context: true } }
  let(:settings) { { some_setting: 42 } }
  let(:value) { { some_context: true, settings: settings } }
  let(:error_details) { 'some error details' }
  let(:err_message_context) { { details: error_details } }

  # rubocop:disable Layout/LineLength -- keep all the class and method fixtures as single-liners easier scanning/editing
  # Classes

  let(:settings_initializer_class) { RemoteDevelopment::Settings::SettingsInitializer }
  let(:current_settings_reader_class) { RemoteDevelopment::Settings::CurrentSettingsReader }
  let(:extensions_gallery_metadata_generator_class) { RemoteDevelopment::Settings::ExtensionsGalleryMetadataGenerator }
  let(:env_var_reader_class) { RemoteDevelopment::Settings::EnvVarReader }
  let(:extensions_gallery_validator_class) { RemoteDevelopment::Settings::ExtensionsGalleryValidator }
  let(:extensions_gallery_metadata_validator_class) { RemoteDevelopment::Settings::ExtensionsGalleryMetadataValidator }
  let(:reconciliation_interval_seconds_validator_class) { RemoteDevelopment::Settings::ReconciliationIntervalSecondsValidator }

  # Methods

  let(:settings_initializer_method) { settings_initializer_class.singleton_method(:init) }
  let(:current_settings_reader_method) { current_settings_reader_class.singleton_method(:read) }
  let(:extensions_gallery_metadata_generator_method) { extensions_gallery_metadata_generator_class.singleton_method(:generate) }
  let(:env_var_reader_method) { env_var_reader_class.singleton_method(:read) }
  let(:extensions_gallery_validator_method) { extensions_gallery_validator_class.singleton_method(:validate) }
  let(:extensions_gallery_metadata_validator_method) { extensions_gallery_metadata_validator_class.singleton_method(:validate) }
  let(:reconciliation_interval_seconds_validator_method) { reconciliation_interval_seconds_validator_class.singleton_method(:validate) }

  # Subject

  subject(:response) { described_class.get_settings(input_value) }

  before do
    allow(settings_initializer_class).to receive(:method).with(:init) { settings_initializer_method }
    allow(current_settings_reader_class).to receive(:method).with(:read) { current_settings_reader_method }
    allow(extensions_gallery_metadata_generator_class).to(receive(:method).with(:generate)) { extensions_gallery_metadata_generator_method }
    allow(env_var_reader_class).to receive(:method).with(:read) { env_var_reader_method }
    allow(extensions_gallery_validator_class).to(receive(:method).with(:validate)) { extensions_gallery_validator_method }
    allow(extensions_gallery_metadata_validator_class).to(receive(:method).with(:validate)) { extensions_gallery_metadata_validator_method }
    allow(reconciliation_interval_seconds_validator_class).to(receive(:method).with(:validate)) { reconciliation_interval_seconds_validator_method }

    stub_method_to_modify_and_return_value(settings_initializer_method, expected_value: input_value, returned_value: value)
    stub_methods_to_return_value(extensions_gallery_metadata_generator_method)
  end
  # rubocop:enable Layout/LineLength

  context 'when all steps are successful' do
    before do
      stub_methods_to_return_ok_result(
        current_settings_reader_method,
        env_var_reader_method,
        extensions_gallery_validator_method,
        extensions_gallery_metadata_validator_method,
        reconciliation_interval_seconds_validator_method
      )
    end

    it 'returns a success response with the settings as the payload' do
      expect(response).to eq({
        status: :success,
        settings: settings
      })
    end
  end

  context 'when the CurrentSettingsReader returns an err Result' do
    before do
      stub_methods_to_return_err_result(
        method: current_settings_reader_method,
        message_class: RemoteDevelopment::Messages::SettingsCurrentSettingsReadFailed
      )
    end

    it 'returns an error response' do
      expect(response).to eq({
        status: :error,
        message: "Settings current settings read failed: #{error_details}",
        reason: :internal_server_error
      })
    end
  end

  context 'when the EnvVarReader returns an err Result' do
    before do
      stub_methods_to_return_ok_result(current_settings_reader_method)
      stub_methods_to_return_err_result(
        method: env_var_reader_method,
        message_class: RemoteDevelopment::Messages::SettingsEnvironmentVariableReadFailed
      )
    end

    it 'returns an error response' do
      expect(response).to eq({
        status: :error,
        message: "Settings environment variable read failed: #{error_details}",
        reason: :internal_server_error
      })
    end
  end

  context 'when the ExtensionsGalleryValidator returns an err Result' do
    before do
      stub_methods_to_return_ok_result(current_settings_reader_method, env_var_reader_method)
      stub_methods_to_return_err_result(
        method: extensions_gallery_validator_method,
        message_class: RemoteDevelopment::Messages::SettingsVscodeExtensionsGalleryValidationFailed
      )
    end

    it 'returns an error response' do
      expect(response).to eq({
        status: :error,
        message: "Settings VSCode extensions gallery validation failed: #{error_details}",
        reason: :internal_server_error
      })
    end
  end

  context 'when the ExtensionsGalleryMetadataValidator returns an err Result' do
    before do
      stub_methods_to_return_ok_result(
        current_settings_reader_method,
        env_var_reader_method,
        extensions_gallery_validator_method
      )
      stub_methods_to_return_err_result(
        method: extensions_gallery_metadata_validator_method,
        message_class: RemoteDevelopment::Messages::SettingsVscodeExtensionsGalleryMetadataValidationFailed
      )
    end

    it 'returns an error response' do
      expect(response).to eq({
        status: :error,
        message: "Settings VSCode extensions gallery metadata validation failed: #{error_details}",
        reason: :internal_server_error
      })
    end
  end

  context 'when the FullReconciliationIntervalSecondsValidator returns an err Result' do
    before do
      stub_methods_to_return_ok_result(
        current_settings_reader_method,
        env_var_reader_method,
        extensions_gallery_validator_method,
        extensions_gallery_metadata_validator_method
      )
      stub_methods_to_return_err_result(
        method: reconciliation_interval_seconds_validator_method,
        message_class: RemoteDevelopment::Messages::SettingsFullReconciliationIntervalSecondsValidationFailed
      )
    end

    it 'returns an error response' do
      expect(response).to eq({
        status: :error,
        message: "Settings full reconciliation interval seconds validation failed: #{error_details}",
        reason: :internal_server_error
      })
    end
  end

  context 'when the SettingsPartialReconciliationIntervalSecondsValidationFailed returns an err Result' do
    before do
      stub_methods_to_return_ok_result(
        current_settings_reader_method,
        env_var_reader_method,
        extensions_gallery_validator_method,
        extensions_gallery_metadata_validator_method,
        reconciliation_interval_seconds_validator_method
      )
      stub_methods_to_return_err_result(
        method: reconciliation_interval_seconds_validator_method,
        message_class: RemoteDevelopment::Messages::SettingsPartialReconciliationIntervalSecondsValidationFailed
      )
    end

    it 'returns an error response' do
      expect(response).to eq({
        status: :error,
        message: "Settings partial reconciliation interval seconds validation failed: #{error_details}",
        reason: :internal_server_error
      })
    end
  end

  context 'when an invalid Result is returned' do
    before do
      stub_methods_to_return_ok_result(current_settings_reader_method)
      stub_methods_to_return_err_result(
        method: env_var_reader_method,
        message_class: RemoteDevelopment::Messages::WorkspaceCreateSuccessful
      )
    end

    it 'raises an UnmatchedResultError' do
      expect { response }.to raise_error(RemoteDevelopment::UnmatchedResultError)
    end
  end
end
