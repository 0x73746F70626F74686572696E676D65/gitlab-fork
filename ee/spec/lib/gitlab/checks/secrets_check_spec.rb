# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::SecretsCheck, feature_category: :secret_detection do
  include_context 'secrets check context'

  describe '#validate!' do
    context 'when application setting is disabled' do
      before do
        Gitlab::CurrentSettings.update!(pre_receive_secret_detection_enabled: false)
      end

      it 'skips the check' do
        expect(secrets_check.validate!).to be_nil
      end
    end

    context 'when application and project settings are enabled' do
      before do
        Gitlab::CurrentSettings.update!(pre_receive_secret_detection_enabled: true)
        project.security_setting.update!(pre_receive_secret_detection_enabled: true)
      end

      context 'when instance is dedicated' do
        before do
          Gitlab::CurrentSettings.update!(gitlab_dedicated_instance: true)
        end

        context 'when license is not ultimate' do
          it 'skips the check' do
            expect(secrets_check.validate!).to be_nil
          end
        end

        context 'when license is ultimate' do
          before do
            stub_licensed_features(pre_receive_secret_detection: true)
          end

          context 'when deleting the branch' do
            it 'skips the check' do
              expect(delete_branch.validate!).to be_nil
            end
          end

          it_behaves_like 'scan passed'
          it_behaves_like 'scan detected secrets'
          it_behaves_like 'scan detected secrets but some errors occured'
          it_behaves_like 'scan timed out'
          it_behaves_like 'scan failed to initialize'
          it_behaves_like 'scan failed with invalid input'
          it_behaves_like 'scan skipped due to invalid status'
          it_behaves_like 'scan skipped when a commit has special bypass flag'
          it_behaves_like 'scan skipped when secret_push_protection.skip_all push option is passed'
        end
      end

      context 'when instance is GitLab.com' do
        before do
          Gitlab::CurrentSettings.update!(gitlab_dedicated_instance: false)
          stub_saas_features(beta_rollout_pre_receive_secret_detection: true)
          project.security_setting.update!(pre_receive_secret_detection_enabled: true)
        end

        context 'when license is not ultimate' do
          it 'skips the check' do
            expect(secrets_check.validate!).to be_nil
          end
        end

        context 'when license is ultimate' do
          before do
            stub_licensed_features(pre_receive_secret_detection: true)
          end

          it_behaves_like 'scan passed'
          it_behaves_like 'scan detected secrets'
          it_behaves_like 'scan detected secrets but some errors occured'
          it_behaves_like 'scan timed out'
          it_behaves_like 'scan failed to initialize'
          it_behaves_like 'scan failed with invalid input'
          it_behaves_like 'scan skipped due to invalid status'
          it_behaves_like 'scan skipped when a commit has special bypass flag'
          it_behaves_like 'scan skipped when secret_push_protection.skip_all push option is passed'
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(pre_receive_secret_detection_push_check: false)
          end

          it 'skips the check' do
            expect(secrets_check.validate!).to be_nil
          end
        end

        context 'when project setting is disabled' do
          before do
            project.security_setting.update!(pre_receive_secret_detection_enabled: false)
          end

          it 'skips the check' do
            expect(secrets_check.validate!).to be_nil
          end
        end

        context 'when project does not have security settings' do
          before do
            stub_licensed_features(pre_receive_secret_detection: true)
            Gitlab::CurrentSettings.update!(pre_receive_secret_detection_enabled: true)
          end

          it 'skips the check' do
            allow(project).to receive(:security_setting).and_return(nil)

            expect(secrets_check.validate!).to be_nil
          end
        end
      end

      context 'when instance is not dedicated or GitLab.com' do
        before do
          Gitlab::CurrentSettings.update!(gitlab_dedicated_instance: false)
          stub_saas_features(beta_rollout_pre_receive_secret_detection: false)
          project.security_setting.update!(pre_receive_secret_detection_enabled: true)
        end

        context 'when license is not ultimate' do
          it 'skips the check' do
            expect(secrets_check.validate!).to be_nil
          end
        end

        context 'when license is ultimate' do
          before do
            stub_licensed_features(pre_receive_secret_detection: true)
          end

          it 'skips the check' do
            expect(secrets_check.validate!).to be_nil
          end
        end
      end
    end

    context 'when application setting is enabled' do
      before do
        Gitlab::CurrentSettings.update!(pre_receive_secret_detection_enabled: true)
      end

      context 'when project setting is disabled' do
        before do
          project.security_setting.update!(pre_receive_secret_detection_enabled: false)
        end

        context 'when instance is dedicated' do
          before do
            Gitlab::CurrentSettings.update!(gitlab_dedicated_instance: true)
            stub_saas_features(beta_rollout_pre_receive_secret_detection: false)
          end

          context 'when license is ultimate' do
            before do
              stub_licensed_features(pre_receive_secret_detection: true)
            end

            it 'skips the check' do
              expect(secrets_check.validate!).to be_nil
            end
          end
        end

        context 'when instance is GitLab.com' do
          before do
            Gitlab::CurrentSettings.update!(gitlab_dedicated_instance: false)
            stub_saas_features(beta_rollout_pre_receive_secret_detection: true)
          end

          context 'when license is ultimate' do
            before do
              stub_licensed_features(pre_receive_secret_detection: true)
            end

            it 'skips the check' do
              expect(secrets_check.validate!).to be_nil
            end
          end
        end
      end
    end
  end
end
