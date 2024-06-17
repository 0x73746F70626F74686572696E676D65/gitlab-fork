# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::ApplicationSettingsHelper, feature_category: :shared do
  describe '.visible_attributes' do
    it 'contains personal access token parameters' do
      expect(visible_attributes).to include(*%i[max_personal_access_token_lifetime])
    end

    it 'contains anthropic_api_key value' do
      expect(visible_attributes).to include(*%i[anthropic_api_key])
    end

    it 'contains duo_features_enabled parameters' do
      expect(visible_attributes).to include(*%i[duo_features_enabled lock_duo_features_enabled])
    end

    it 'contains zoekt parameters' do
      expect(visible_attributes).to include(*%i[zoekt_auto_index_root_namespace zoekt_indexing_enabled zoekt_indexing_paused
        zoekt_search_enabled])
    end

    context 'when identity verification is enabled' do
      before do
        stub_saas_features(identity_verification: true)
      end

      it 'contains telesign values' do
        expect(visible_attributes).to include(*%i[telesign_customer_xid telesign_api_key])
      end

      it 'contains arkose values' do
        expect(visible_attributes).to include(*%i[
          arkose_labs_client_secret
          arkose_labs_client_xid
          arkose_labs_namespace
          arkose_labs_private_api_key
          arkose_labs_public_api_key
        ])
      end
    end

    context 'when identity verification is not enabled' do
      it 'does not contain telesign values' do
        expect(visible_attributes).not_to include(*%i[telesign_customer_xid telesign_api_key])
      end

      it 'does not contain arkose values' do
        expect(visible_attributes).not_to include(*%i[
          arkose_labs_client_secret
          arkose_labs_client_xid
          arkose_labs_namespace
          arkose_labs_private_api_key
          arkose_labs_public_api_key
        ])
      end
    end
  end

  describe '.registration_features_can_be_prompted?' do
    subject { helper.registration_features_can_be_prompted? }

    context 'without a valid license' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      context 'when service ping is enabled' do
        before do
          stub_application_setting(usage_ping_enabled: true)
        end

        it { is_expected.to be_falsey }
      end

      context 'when service ping is disabled' do
        before do
          stub_application_setting(usage_ping_enabled: false)
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'with a license' do
      let(:license) { build(:license) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it { is_expected.to be_falsey }

      context 'when service ping is disabled' do
        before do
          stub_application_setting(usage_ping_enabled: false)
        end

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '.deletion_protection_data' do
    let_it_be(:application_setting) { build(:application_setting) }

    before do
      application_setting.deletion_adjourned_period = 1

      helper.instance_variable_set(:@application_setting, application_setting)
    end

    subject { helper.deletion_protection_data }

    it { is_expected.to eq({ deletion_adjourned_period: 1 }) }
  end

  describe '.git_abuse_rate_limit_data', feature_category: :insider_threat do
    let_it_be(:application_setting) { build(:application_setting) }

    before do
      application_setting.max_number_of_repository_downloads = 1
      application_setting.max_number_of_repository_downloads_within_time_period = 2
      application_setting.git_rate_limit_users_allowlist = %w[username1 username2]
      application_setting.git_rate_limit_users_alertlist = [3, 4]
      application_setting.auto_ban_user_on_excessive_projects_download = true

      helper.instance_variable_set(:@application_setting, application_setting)
    end

    subject { helper.git_abuse_rate_limit_data }

    it 'returns the expected data' do
      is_expected.to eq({ max_number_of_repository_downloads: 1,
                          max_number_of_repository_downloads_within_time_period: 2,
                          git_rate_limit_users_allowlist: %w[username1 username2],
                          git_rate_limit_users_alertlist: [3, 4],
                          auto_ban_user_on_excessive_projects_download: 'true' })
    end
  end

  describe '#sync_purl_types_checkboxes', feature_category: :software_composition_analysis do
    let_it_be(:application_setting) { build(:application_setting) }
    let_it_be(:enabled_purl_types) { [1, 5] }

    before do
      application_setting.package_metadata_purl_types = enabled_purl_types

      helper.instance_variable_set(:@application_setting, application_setting)
    end

    it 'returns correctly checked purl type checkboxes' do
      helper.gitlab_ui_form_for(application_setting, url: '/admin/application_settings/security_and_compliance') do |form|
        result = helper.sync_purl_types_checkboxes(form)

        expected = ::Enums::Sbom.purl_types.map do |name, num|
          if enabled_purl_types.include?(num)
            have_checked_field(name, with: num)
          else
            have_unchecked_field(name, with: num)
          end
        end

        expect(result).to match_array(expected)
      end
    end
  end

  describe '#zoekt_settings_checkboxes', feature_category: :global_search do
    let_it_be(:application_setting) { build(:application_setting) }

    before do
      application_setting.zoekt_auto_index_root_namespace = false
      application_setting.zoekt_indexing_enabled = true
      application_setting.zoekt_indexing_paused = false
      application_setting.zoekt_search_enabled = true
      helper.instance_variable_set(:@application_setting, application_setting)
    end

    it 'returns correctly checked checkboxes' do
      helper.gitlab_ui_form_for(application_setting, url: advanced_search_admin_application_settings_path) do |form|
        result = helper.zoekt_settings_checkboxes(form)
        expect(result[0]).not_to have_checked_field('Index all the namespaces', with: 1)
        expect(result[1]).to have_checked_field('Enable indexing for exact code search', with: 1)
        expect(result[2]).not_to have_checked_field('Pause indexing for exact code search', with: 1)
        expect(result[3]).to have_checked_field('Enable exact code search', with: 1)
      end
    end
  end
end
