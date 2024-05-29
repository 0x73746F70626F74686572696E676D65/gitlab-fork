# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::NamespaceSettings::AssignAttributesService, feature_category: :groups_and_projects do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:user) { create(:user) }

  subject(:update_settings) { NamespaceSettings::AssignAttributesService.new(user, group, params).execute }

  describe '#execute' do
    context 'when prevent_forking_outside_group param present' do
      let(:params) { { prevent_forking_outside_group: true } }

      context 'as a normal user' do
        it 'does not change settings' do
          update_settings

          expect { group.save! }
            .not_to(change { group.namespace_settings.prevent_forking_outside_group })
        end

        it 'registers an error' do
          update_settings

          expect(group.errors[:prevent_forking_outside_group]).to include('Prevent forking setting was not saved')
        end
      end

      context 'as a group owner' do
        before_all do
          group.add_owner(user)
        end

        context 'for a group that does not have prevent forking feature' do
          it 'does not change settings' do
            update_settings

            expect { group.save! }
              .not_to(change { group.namespace_settings.prevent_forking_outside_group })
          end

          it 'registers an error' do
            update_settings

            expect(group.errors[:prevent_forking_outside_group]).to include('Prevent forking setting was not saved')
          end
        end

        context 'for a group that has prevent forking feature' do
          before do
            stub_licensed_features(group_forking_protection: true)
          end

          it 'changes settings' do
            update_settings
            group.save!

            expect(group.namespace_settings.reload.prevent_forking_outside_group).to eq(true)
          end
        end
      end
    end

    context 'when service_access_tokens_expiration_enforced param present' do
      let(:params) { { service_access_tokens_expiration_enforced: false } }

      before_all do
        group.add_owner(user)
      end

      context 'when service accounts is not available' do
        it 'does not change settings' do
          expect { update_settings }
            .not_to(change { group.namespace_settings.reload.service_access_tokens_expiration_enforced })
        end

        it 'registers an error' do
          update_settings

          expect(group.errors[:service_access_tokens_expiration_enforced])
            .to include('Service access tokens expiration enforced setting was not saved')
        end
      end

      context 'when service accounts is available' do
        before do
          stub_licensed_features(service_accounts: true)
        end

        it 'changes settings' do
          update_settings

          expect(group.namespace_settings.attributes["service_access_tokens_expiration_enforced"])
            .to eq(false)
        end

        context 'when group is not top level group' do
          let(:parent_group) { create(:group) }

          before do
            group.parent = parent_group
            group.save!
          end

          it 'registers an error' do
            update_settings

            expect(group.errors[:service_access_tokens_expiration_enforced])
              .to include('Service access tokens expiration enforced setting was not saved')
          end
        end
      end
    end

    context 'when ai settings change', :saas do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
        stub_ee_application_setting(should_check_namespace_plan: true)
        stub_licensed_features(ai_features: true)
      end

      context 'when experiment_features_enabled changes' do
        let(:params) { { experiment_features_enabled: true } }

        it 'publishes an event' do
          expect { update_settings }.to publish_event(::NamespaceSettings::AiRelatedSettingsChangedEvent)
            .with(group_id: group.id)
        end
      end

      context 'when experiment_features setting does not change' do
        let(:params) { { experiment_features_enabled: false } }

        it 'does not publish an event' do
          expect { update_settings }.not_to publish_event(::NamespaceSettings::AiRelatedSettingsChangedEvent)
        end
      end
    end
  end
end
