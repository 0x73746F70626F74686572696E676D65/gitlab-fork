# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/general.html.haml' do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:admin) }
  let_it_be(:app_settings) { build(:application_setting) }

  let(:duo_chat_cut_off_date) { Time.zone.parse('2024-03-15T00:00:00Z') }
  let(:duo_chat_service_data) do
    CloudConnector::SelfManaged::AvailableServiceData.new(:duo_chat, duo_chat_cut_off_date, %w[duo_pro])
  end

  subject { rendered }

  before do
    assign(:application_setting, app_settings)
    allow(view).to receive(:current_user).and_return(user)

    allow(CloudConnector::AvailableServices).to receive(:find_by_name).with(:duo_chat)
                                                                      .and_return(duo_chat_service_data)
  end

  describe 'maintenance mode' do
    let(:license_allows) { true }

    before do
      allow(Gitlab::Geo).to receive(:license_allows?).and_return(license_allows)

      render
    end

    context 'when license does not allow' do
      let(:license_allows) { false }

      it 'does not show the Maintenance mode section' do
        expect(rendered).not_to have_css('#js-maintenance-mode-toggle')
      end
    end

    context 'when license allows' do
      it 'shows the Maintenance mode section' do
        expect(rendered).to have_css('#js-maintenance-mode-toggle')
      end
    end
  end

  describe 'SAML group locks settings' do
    let(:saml_group_sync_enabled) { false }
    let(:settings_text) { 'SAML group membership settings' }

    before do
      allow(view).to receive(:saml_group_sync_enabled?).and_return(saml_group_sync_enabled)

      render
    end

    it { is_expected.not_to match(settings_text) }

    context 'when one or multiple SAML providers are group-sync-enabled' do
      let(:saml_group_sync_enabled) { true }

      it { is_expected.to match(settings_text) }
    end
  end

  describe 'prompt user about registration features' do
    context 'with no license and service ping disabled' do
      before do
        allow(License).to receive(:current).and_return(nil)
        stub_application_setting(usage_ping_enabled: false)
      end

      it_behaves_like 'renders registration features prompt', :application_setting_disabled_repository_size_limit
      it_behaves_like 'renders registration features settings link'
    end

    context 'with a valid license and service ping disabled' do
      let(:current_license) { build(:license) }

      before do
        allow(License).to receive(:current).and_return(current_license)
        stub_application_setting(usage_ping_enabled: false)
      end

      it_behaves_like 'does not render registration features prompt', :application_setting_disabled_repository_size_limit
    end
  end

  describe 'add license' do
    let(:current_license) { build(:license) }

    before do
      assign(:new_license, current_license)
      render
    end

    it 'shows the Add License section' do
      expect(rendered).to have_css('#js-add-license-toggle')
    end
  end

  describe 'sign-up restrictions' do
    it 'does not render complexity setting attributes' do
      render

      expect(rendered).to match 'id="js-signup-form"'
      expect(rendered).not_to match 'data-password-lowercase-required'
    end

    context 'when password_complexity license is available' do
      before do
        stub_licensed_features(password_complexity: true)
      end

      it 'renders complexity setting attributes' do
        render

        expect(rendered).to match ' data-password-lowercase-required='
        expect(rendered).to match ' data-password-number-required='
      end
    end
  end

  describe 'instance-level ai-powered beta features settings', feature_category: :duo_chat do
    before do
      allow(::Gitlab).to receive(:org_or_com?).and_return(gitlab_org_or_com?)
      stub_licensed_features(ai_chat: false)
    end

    shared_examples 'does not render AI Beta features toggle' do
      it 'does not render AI Beta features toggle' do
        render
        expect(rendered).not_to have_field('application_setting_instance_level_ai_beta_features_enabled')
      end
    end

    context 'when on .com or .org' do
      let(:gitlab_org_or_com?) { true }

      it_behaves_like 'does not render AI Beta features toggle'
    end

    context 'when not on .com and not on .org' do
      let(:gitlab_org_or_com?) { false }

      context 'with license', :with_license do
        context 'with :ai_chat feature available' do
          before do
            stub_licensed_features(ai_chat: true)
          end

          context 'when before the cut off date date' do
            around do |example|
              travel_to(duo_chat_cut_off_date - 1.day) do
                example.run
              end
            end

            it 'renders AI Beta features toggle' do
              render
              expect(rendered).to have_field('application_setting_instance_level_ai_beta_features_enabled')
            end
          end

          context 'when after the cut off date' do
            around do |example|
              travel_to(duo_chat_cut_off_date + 1.second) do
                example.run
              end
            end

            it 'does not render AI Beta features toggle' do
              render
              expect(rendered).not_to have_field('application_setting_instance_level_ai_beta_features_enabled')
            end
          end

          context 'when cut off date is nil' do
            let(:duo_chat_cut_off_date) { nil }

            it 'renders AI Beta features toggle' do
              render
              expect(rendered).to have_field('application_setting_instance_level_ai_beta_features_enabled')
            end
          end
        end

        context 'with :ai_chat feature not available' do
          before do
            stub_licensed_features(ai_chat: false)
          end

          it_behaves_like 'does not render AI Beta features toggle'
        end
      end

      context 'with no license', :without_license do
        it_behaves_like 'does not render AI Beta features toggle'
      end
    end
  end

  describe 'entire instance-level ai-powered menu section visibility', feature_category: :duo_chat do
    let(:before_duo_chat_cut_off_date) { duo_chat_cut_off_date - 1.second }
    let(:after_duo_chat_cut_off_date) { duo_chat_cut_off_date + 1.second }

    where(:current_date, :ai_chat_available, :expect_section_is_visible) do
      ref(:before_duo_chat_cut_off_date) | false | false
      ref(:before_duo_chat_cut_off_date) | true  | true
      ref(:after_duo_chat_cut_off_date)  | false | false
      ref(:after_duo_chat_cut_off_date)  | true  | false
    end

    with_them do
      it 'sets entire ai-powered menu section visibility correctly' do
        allow(::Gitlab).to receive(:org_or_com?).and_return(false)
        stub_licensed_features(ai_chat: ai_chat_available)

        travel_to(current_date) do
          render

          if expect_section_is_visible
            expect(rendered).to have_content('AI-powered features')
          else
            expect(rendered).not_to have_content('AI-powered features')
          end
        end
      end
    end
  end

  describe 'private profile restrictions', feature_category: :user_management do
    it 'renders correct ee partial' do
      render

      expect(rendered).to render_template('admin/application_settings/_private_profile_restrictions')
    end
  end
end
