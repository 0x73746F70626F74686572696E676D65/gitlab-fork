# frozen_string_literal: true

require "spec_helper"

RSpec.describe Admin::ApplicationSettingsHelper, feature_category: :code_suggestions do
  using RSpec::Parameterized::TableSyntax

  describe 'AI-Powered features settings for Self-Managed instances' do
    describe '#ai_powered_description' do
      subject { helper.ai_powered_description }

      it { is_expected.to include 'https://docs.gitlab.com/ee/user/ai_features.html' }
    end

    describe '#ai_powered_testing_agreement' do
      subject { helper.ai_powered_testing_agreement }

      it { is_expected.to include 'https://about.gitlab.com/handbook/legal/testing-agreement/' }
    end
  end

  describe '#admin_display_ai_powered_toggle?', :freeze_time, feature_category: :duo_chat do
    let(:feature_enabled) { true }
    let(:past) { Time.current - 1.second }
    let(:future) { Time.current + 1.second }
    let(:duo_chat_service_data) do
      CloudConnector::SelfManaged::AvailableServiceData.new(:duo_chat, duo_chat_cut_off_date,  %w[duo_pro])
    end

    before do
      stub_licensed_features(ai_chat: feature_enabled)

      allow(CloudConnector::AvailableServices).to receive(:find_by_name).with(:duo_chat)
                                                                        .and_return(duo_chat_service_data)
    end

    where(:duo_chat_cut_off_date, :feature_available, :expectation) do
      ref(:past) | true | false
      ref(:past) | false | false
      ref(:future) | true | true
      ref(:future) | false | false
      nil | true | true
      nil | false | false
    end

    with_them do
      it 'returns expectation' do
        stub_licensed_features(ai_chat: feature_available)

        expect(helper.admin_display_ai_powered_toggle?).to eq(expectation)
      end
    end
  end
end
