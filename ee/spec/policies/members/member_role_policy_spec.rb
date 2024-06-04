# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::MemberRolePolicy, feature_category: :system_access do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:permissions) { [:admin_member_role, :read_member_role] }

  subject(:policy) { described_class.new(user, member_role) }

  describe 'rules' do
    context 'for group member roles' do
      let_it_be(:member_role) { create(:member_role, namespace: group) }

      context 'without the custom roles feature' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        before_all do
          group.add_owner(user)
        end

        it { is_expected.to be_disallowed(*permissions) }
      end

      context 'with the custom roles feature' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context 'when non member' do
          it { is_expected.to be_disallowed(*permissions) }
        end

        context 'when maintainer' do
          before_all do
            group.add_maintainer(user)
          end

          it { is_expected.to be_disallowed(*permissions) }
        end

        context 'when owner' do
          before_all do
            group.add_owner(user)
          end

          it { is_expected.to be_allowed(*permissions) }
        end

        context 'when admin' do
          before_all do
            user.update!(admin: true)
          end

          context 'when admin', :enable_admin_mode do
            before_all do
              user.update!(admin: true)
            end

            it { is_expected.to be_allowed(*permissions) }
          end
        end
      end
    end

    context 'for instance level member roles' do
      let_it_be(:member_role) { create(:member_role, :instance) }

      context 'without the custom roles feature', :enable_admin_mode do
        before do
          stub_licensed_features(custom_roles: false)
        end

        before_all do
          user.update!(admin: true)
        end

        it { is_expected.to be_disallowed(*permissions) }
      end

      context 'with the custom roles feature' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context 'when non member' do
          it { is_expected.to be_disallowed(*permissions) }
        end

        context 'when group maintainer' do
          before_all do
            group.add_maintainer(user)
          end

          it { is_expected.to be_disallowed(*permissions) }
        end

        context 'when group owner' do
          before_all do
            group.add_owner(user)
          end

          it { is_expected.to be_allowed(:read_member_role) }
          it { is_expected.to be_disallowed(:admin_member_role) }
        end

        context 'when instance admin' do
          before_all do
            user.update!(admin: true)
          end

          context 'when admin mode is enabled', :enable_admin_mode do
            it { is_expected.to be_allowed(*permissions) }
          end

          context 'when admin mode is disabled' do
            it { is_expected.to be_disallowed(*permissions) }
          end
        end
      end
    end
  end
end
