# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::RemoteDevelopment::Settings::CurrentSettingsReader, feature_category: :remote_development do
  include ResultMatchers

  let(:overridden_setting_type) { String }
  let(:overridden_setting_value_from_current_settings) { "value_from_current_settings" }

  let(:value) do
    {
      settings: {
        non_overridden_setting: "not_overridden",
        overridden_setting: "original_value"
      },
      setting_types: {
        non_overridden_setting: String,
        overridden_setting: overridden_setting_type
      }
    }
  end

  subject(:result) do
    described_class.read(value)
  end

  before do
    create(:application_setting)
    stub_application_setting(overridden_setting: overridden_setting_value_from_current_settings)
  end

  context "when there are no errors" do
    it "returns ::Gitlab::CurrentSettings overridden settings and non-overridden settings" do
      expect(result).to eq(Result.ok(
        {
          settings: {
            non_overridden_setting: "not_overridden",
            overridden_setting: overridden_setting_value_from_current_settings
          },
          setting_types: {
            non_overridden_setting: String,
            overridden_setting: String
          }
        }
      ))
    end
  end

  context "when the type from GitLab::CurrentSettings does not match the declared remote development setting type" do
    let(:overridden_setting_type) { Integer }

    it "returns an err Result containing a Gitlab::CurrentSettings read failed message with details" do
      expect(result).to be_err_result(
        RemoteDevelopment::Messages::SettingsCurrentSettingsReadFailed.new(
          details: "Gitlab::CurrentSettings.overridden_setting type of 'String' " \
            "did not match initialized Remote Development Settings type of '#{overridden_setting_type}'." # rubocop:disable Layout/LineEndStringConcatenationIndentation -- use default RubyMine formatting
        )
      )
    end
  end
end
