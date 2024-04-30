# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Configuration::SetPreReceiveSecretDetection, feature_category: :secret_detection do
  describe '#execute' do
    let_it_be(:security_setting) { create(:project_security_setting, pre_receive_secret_detection_enabled: false) }
    let_it_be(:current_user) { create(:user, :admin) }

    context 'when namespace is project' do
      let_it_be(:namespace) { security_setting.project }

      it 'returns attribute value' do
        expect(described_class.execute(current_user: current_user, namespace: namespace,
          enable: true)).to have_attributes(errors: be_blank, payload: include(enabled: true))
        expect(described_class.execute(current_user: current_user, namespace: namespace,
          enable: false)).to have_attributes(errors: be_blank, payload: include(enabled: false))
      end

      it 'changes the attribute' do
        expect { described_class.execute(current_user: current_user, namespace: namespace, enable: true) }
          .to change { security_setting.reload.pre_receive_secret_detection_enabled }
          .from(false).to(true)
        expect { described_class.execute(current_user: current_user, namespace: namespace, enable: true) }
          .not_to change { security_setting.reload.pre_receive_secret_detection_enabled }
        expect { described_class.execute(current_user: current_user, namespace: namespace, enable: false) }
          .to change { security_setting.reload.pre_receive_secret_detection_enabled }
          .from(true).to(false)
        expect { described_class.execute(current_user: current_user, namespace: namespace, enable: false) }
          .not_to change { security_setting.reload.pre_receive_secret_detection_enabled }
      end

      context 'when attribute changes from false to true' do
        it 'creates an audit event with the correct message' do
          expect { described_class.execute(current_user: current_user, namespace: namespace, enable: true) }
            .to change { AuditEvent.count }.by(1)
          expect(AuditEvent.last.details[:custom_message]).to eq(
            "Changed pre_receive_secret_detection_enabled from false to true")
        end
      end

      context 'when attribute changes from true to false' do
        let(:security_setting2) { create(:project_security_setting, pre_receive_secret_detection_enabled: true) }
        let(:namespace2) { security_setting2.project }

        it 'creates an audit event with the correct message' do
          expect { described_class.execute(current_user: current_user, namespace: namespace2, enable: false) }
            .to change { AuditEvent.count }.by(1)
          expect(AuditEvent.last.details[:custom_message]).to eq(
            "Changed pre_receive_secret_detection_enabled from true to false")
        end
      end

      context 'when fields are invalid' do
        it 'returns nil and error' do
          expect(described_class.execute(current_user: current_user, namespace: namespace,
            enable: nil)).to have_attributes(errors: be_present, payload: include(enabled: nil))
        end

        it 'does not change the attribute' do
          expect { described_class.execute(current_user: current_user, namespace: namespace, enable: nil) }
            .not_to change { security_setting.reload.pre_receive_secret_detection_enabled }
        end
      end
    end
  end
end
