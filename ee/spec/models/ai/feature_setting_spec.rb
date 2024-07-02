# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FeatureSetting, feature_category: :custom_models do
  subject { build(:ai_feature_setting) }

  it { is_expected.to belong_to(:self_hosted_model) }
  it { is_expected.to validate_presence_of(:feature) }
  it { is_expected.to validate_uniqueness_of(:feature).ignoring_case_sensitivity }
  it { is_expected.to validate_presence_of(:provider) }

  context 'when feature setting is self hosted' do
    let(:feature_setting) { build(:ai_feature_setting) }

    it { expect(feature_setting).to validate_presence_of(:self_hosted_model) }
    it { expect(feature_setting.provider_title).to eq('Self-Hosted Model (mistral-7b-ollama-api)') }
  end

  context 'when feature setting is vendored' do
    let(:feature_setting) { build(:ai_feature_setting, provider: :vendored) }

    it { expect(feature_setting.provider_title).to eq('GitLab AI Vendor') }
  end

  context 'when feature setting is disabled' do
    let(:feature_setting) { build(:ai_feature_setting, provider: :disabled) }

    it { expect(feature_setting.provider_title).to eq('Disabled') }
  end

  describe '#code_suggestions_self_hosted?' do
    where(:feature, :provider, :code_suggestions_self_hosted) do
      [
        [:code_generations, :self_hosted, true],
        [:code_generations, :vendored, false],
        [:code_completions, :self_hosted, true],
        [:code_generations, :vendored, false],
        [:duo_chat, :self_hosted, false]
      ]
    end

    with_them do
      it 'returns whether code generations or completions are self hosted' do
        create(:ai_feature_setting, feature: feature, provider: provider)

        expect(described_class.code_suggestions_self_hosted?).to eq(code_suggestions_self_hosted)
      end
    end
  end
end
