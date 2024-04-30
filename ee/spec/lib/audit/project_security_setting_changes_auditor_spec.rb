# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Audit::ProjectSecuritySettingChangesAuditor, feature_category: :audit_events do
  using RSpec::Parameterized::TableSyntax
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project_security_setting) { create(:project_security_setting) }

    let_it_be(:project_security_setting_auditor_instance) do
      described_class.new(current_user: user, model: project_security_setting)
    end

    before do
      stub_licensed_features(extended_audit_events: true, external_audit_events: true)
    end

    context 'when project_security setting is updated' do
      where(:column, :event, :change_from, :change_to) do
        'pre_receive_secret_detection_enabled' | 'project_security_setting_updated' | true | false
        'pre_receive_secret_detection_enabled' | 'project_security_setting_updated' | false | true
      end

      with_them do
        before do
          project_security_setting.update!(column.to_sym => change_from)
        end

        it 'calls auditor' do
          project_security_setting.update!(column.to_sym => change_to)

          expect(Gitlab::Audit::Auditor).to receive(:audit).with(
            {
              name: event,
              author: user,
              scope: project_security_setting.project,
              target: project_security_setting.project,
              message: "Changed #{column} from #{change_from} to #{change_to}"
            }
          ).and_call_original

          project_security_setting_auditor_instance.execute
        end
      end
    end
  end
end
