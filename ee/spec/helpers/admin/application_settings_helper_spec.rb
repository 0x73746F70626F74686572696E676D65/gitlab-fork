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

  describe '#code_suggestions_purchased?' do
    context 'when code suggestions purchase exists' do
      before do
        gitlab_duo_pro_add_on = build(:gitlab_subscription_add_on)
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on) # rubocop:disable RSpec/FactoryBot/AvoidCreate -- testing that the record exists in the database
      end

      it 'returns true' do
        expect(helper.code_suggestions_purchased?).to eq(true)
      end
    end

    context 'when code suggestions purchase does not exists' do
      it 'returns false' do
        expect(helper.code_suggestions_purchased?).to eq(false)
      end
    end
  end
end
