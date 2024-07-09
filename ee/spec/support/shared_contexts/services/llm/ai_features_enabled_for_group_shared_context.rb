# frozen_string_literal: true

RSpec.shared_context 'with ai features enabled for group' do
  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    allow(group.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
    stub_licensed_features(
      ai_features: true,
      ai_git_command: true,
      generate_description: true
    )
    group.namespace_settings.reload.update!(experiment_features_enabled: true)
  end
end

RSpec.shared_context 'with experiment features disabled for group' do
  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    allow(group.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
    stub_licensed_features(
      ai_git_command: true,
      ai_features: true,
      generate_description: true
    )
    group.namespace_settings.update!(experiment_features_enabled: false)
  end
end

RSpec.shared_context 'with duo features enabled and ai chat available for self-managed' do
  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(false)
    stub_application_setting(duo_features_enabled: true)
    stub_licensed_features(ai_chat: true)
  end
end

RSpec.shared_context 'with duo features enabled and ai chat not available for self-managed' do
  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(false)
    stub_application_setting(duo_features_enabled: true)
    stub_licensed_features(ai_chat: false)
  end
end

RSpec.shared_context 'with duo features disabled and ai chat available for self-managed' do
  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(false)
    stub_application_setting(duo_features_enabled: false)
    stub_licensed_features(ai_chat: true)
  end
end

RSpec.shared_context 'with duo features enabled and ai chat available for group on SaaS' do
  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(ai_chat: true)
    group.namespace_settings.reload.update!(duo_features_enabled: true)
  end
end

RSpec.shared_context 'with duo features enabled and ai chat not available for group on SaaS' do
  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(ai_chat: false)
    group.namespace_settings.reload.update!(duo_features_enabled: true)
  end
end

RSpec.shared_context 'with duo features disabled and ai chat available for group on SaaS' do
  before do
    allow(Gitlab).to receive(:org_or_com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(ai_chat: true)
    group.namespace_settings.reload.update!(duo_features_enabled: false)
  end
end
