# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::DisableAllowRunnerRegistrationOnNamespaceSettingsForGitlabCom, feature_category: :runner do
  let!(:namespace_table) { table(:namespaces) }
  let!(:namespace_settings_table) { table(:namespace_settings) }

  let!(:namespace_0) { namespace_table.create!(name: 'namespace1', type: 'Group', path: 'namespace1') }
  let!(:namespace_0_0) do
    # Child namespaces should not be touched
    namespace_table.create!(name: 'namespace1_1', path: 'namespace1_1', type: 'Group', parent_id: namespace_0.id)
  end

  let!(:namespace_1) { namespace_table.create!(name: 'namespace2', type: 'Group', path: 'namespace2') }
  let!(:namespace_2) { namespace_table.create!(name: 'namespace3', type: 'Group', path: 'namespace3') }
  let!(:namespace_3) { namespace_table.create!(name: 'namespace4', type: 'Group', path: 'namespace4') }

  let!(:namespace_setting_0_0) { namespace_settings_table.create!(namespace_id: namespace_0_0.id) }
  let!(:namespace_setting_0) do
    namespace_settings_table.create!(namespace_id: namespace_0.id, allow_runner_registration_token: true)
  end

  let!(:namespace_setting_2) do
    namespace_settings_table.create!(namespace_id: namespace_2.id, allow_runner_registration_token: false)
  end

  let!(:namespace_setting_3) do
    namespace_settings_table.create!(namespace_id: namespace_3.id, allow_runner_registration_token: true)
  end

  describe '#perform' do
    let(:start_id) { namespace_table.minimum(:id) }
    let(:end_id) { namespace_table.maximum(:id) }

    subject(:perform_migration) do
      described_class.new(
        start_id: start_id,
        end_id: end_id,
        batch_table: :namespaces,
        batch_column: :id,
        sub_batch_size: 2,
        pause_ms: 0,
        connection: ApplicationRecord.connection
      ).perform
    end

    it 'disables the namespace setting for namespaces with settings' do
      expect { perform_migration }
        .to change { namespace_setting_0.reload.allow_runner_registration_token }.to(false)
        .and not_change { namespace_setting_0_0.reload.allow_runner_registration_token }
        .and change { namespace_setting(namespace_1.id)&.allow_runner_registration_token }.from(nil).to(false)
        .and not_change { namespace_setting_2.reload.allow_runner_registration_token }
        .and change { namespace_setting_3.reload.allow_runner_registration_token }.to(false)
    end

    context 'with end_id set to start_id' do
      let(:end_id) { start_id }

      it 'disables the namespace setting for first namespace with settings' do
        expect { perform_migration }
          .to change { namespace_setting_0.reload.allow_runner_registration_token }.to(false)
          .and not_change { namespace_setting_0_0.reload.allow_runner_registration_token }
          .and not_change { namespace_setting(namespace_1.id)&.allow_runner_registration_token }
          .and not_change { namespace_setting_2.reload.allow_runner_registration_token }
          .and not_change { namespace_setting_3.reload.allow_runner_registration_token }
      end
    end

    private

    def namespace_setting(id)
      namespace_settings_table.find_by(namespace_id: id)
    end
  end
end
