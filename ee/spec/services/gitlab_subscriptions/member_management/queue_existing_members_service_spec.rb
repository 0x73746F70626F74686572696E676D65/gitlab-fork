# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::QueueExistingMembersService, feature_category: :seat_cost_management do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:group) { create(:group, :public) }

  let_it_be(:users) { create_list(:user, 2) }
  let_it_be(:ultimate_license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:non_billable_member_role) { create(:member_role, :guest, namespace: nil, read_code: true) }
  let_it_be(:billable_member_role) { create(:member_role, :guest, namespace: nil, read_vulnerability: true) }

  let(:members) { source.members_and_requesters.where(user_id: users).to_a }
  let(:params) do
    { access_level: Gitlab::Access::MAINTAINER }
  end

  subject(:create_service) { described_class.new(current_user, members, params).execute }

  shared_examples 'it returns succeess without queuing' do
    it 'returns success' do
      response = create_service

      expect(response.success?).to eq(true)
      expect(response.payload[:members_to_update]).to match_array(members)
      expect(response.payload[:members_queued_for_approval]).to be_nil
    end
  end

  shared_examples 'service queues and returns other members for updates' do |expected_queued, expected_for_updates|
    it "queues #{expected_queued} and updates #{expected_for_updates}" do
      response = nil

      if should_queue_nonbillable?
        expect do
          response = create_service
        end.to change { ::Members::MemberApproval.count }.by(expected_queued)

        if expected_queued > 0
          expect(response.payload[:members_queued_for_approval]).not_to be_nil
          expect(response.payload[:members_queued_for_approval].count).to eq(expected_queued)
          expect(::Members::MemberApproval.last).to eq(response.payload[:members_queued_for_approval].last)
        else
          expect(response.payload[:members_queued_for_approval]).to be_nil
        end

        expect(response.payload[:members_to_update].count).to eq(expected_for_updates)
      else
        response = create_service

        expect(response.payload[:members_queued_for_approval]).to be_nil
        expect(response.payload[:members_to_update].count).to eq(2)
      end

      expect(response.success?).to eq(true)
    end
  end

  shared_examples 'promotion management feature' do
    before do
      source.add_owner(current_user)
    end

    context 'when feature is disabled' do
      it_behaves_like 'it returns succeess without queuing'
    end

    context 'when feature is enabled' do
      before do
        stub_feature_flags(member_promotion_management: true)
      end

      context 'when setting is disabled' do
        it_behaves_like 'it returns succeess without queuing'
      end

      context 'when setting is enabled' do
        before do
          stub_application_setting(enable_member_promotion_management: true)
          allow(License).to receive(:current).and_return(license)
        end

        context 'when subscription plan is not Ultimate' do
          let(:license) { create(:license, plan: License::STARTER_PLAN) }

          before do
            add_non_billable_members
          end

          it_behaves_like 'it returns succeess without queuing'
        end

        context 'when subscription plan is Ultimate' do
          let(:license) { ultimate_license }

          context 'without members' do
            let(:members) { [] }

            it_behaves_like 'it returns succeess without queuing'
          end

          context 'with members' do
            using RSpec::Parameterized::TableSyntax
            where(:user_type, :new_access_level, :member_role_id, :should_queue_nonbillable?) do
              :nonadmin | nil                         | nil          | false
              :nonadmin | nil                         | :billable    | true
              :nonadmin | nil                         | :nonbillable | false
              :nonadmin | nil                         | :invalid     | false
              :nonadmin | ::Gitlab::Access::GUEST     | nil          | false
              :nonadmin | ::Gitlab::Access::DEVELOPER | nil          | true
              :nonadmin | ::Gitlab::Access::GUEST     | :nonbillable | false
              :nonadmin | ::Gitlab::Access::GUEST     | :billable    | true
              :nonadmin | ::Gitlab::Access::GUEST     | :invalid     | false
              :nonadmin | ::Gitlab::Access::DEVELOPER | :nonbillable | true
              :nonadmin | ::Gitlab::Access::DEVELOPER | :billable    | true
              # all scenarios that passed for nonadmin but with admin
              :admin    | nil                         | :billable    | false
              :admin    | ::Gitlab::Access::DEVELOPER | nil          | false
              :admin    | ::Gitlab::Access::GUEST     | :billable    | false
              :admin    | ::Gitlab::Access::DEVELOPER | :nonbillable | false
              :admin    | ::Gitlab::Access::DEVELOPER | :billable    | false
            end

            with_them do
              let(:params) do
                { access_level: new_access_level, member_role_id: nil }
              end

              before do
                allow(current_user).to receive(:can_admin_all_resources?).and_return(true) if user_type == :admin

                params[:member_role_id] = billable_member_role.id if member_role_id == :billable
                params[:member_role_id] = non_billable_member_role.id if member_role_id == :nonbillable
                params[:member_role_id] = 42 if member_role_id == :invalid
              end

              context 'with two non-billable members' do
                before do
                  add_non_billable_members
                end

                it_behaves_like 'service queues and returns other members for updates', 2, 0
              end

              context 'with one billable and one non-billable member' do
                before do
                  source.add_guest(users.first)
                  create(:user_highest_role, :guest, user: users.first)

                  source.add_developer(users.second)
                  create(:user_highest_role, :developer, user: users.second)
                end

                it_behaves_like 'service queues and returns other members for updates', 1, 1
              end

              context 'with two billable members' do
                before do
                  add_billable_members
                end

                it_behaves_like 'service queues and returns other members for updates', 0, 2
              end
            end
          end

          context 'when MemberApproval raises ActiveRecord::RecordInvalid' do
            before do
              add_non_billable_members
              allow(members.first).to receive(:queue_for_approval).and_raise(ActiveRecord::RecordInvalid)
            end

            it 'returns error' do
              response = create_service
              expect(response.error?).to eq(true)
              expect(response.message).to eq('Invalid record while enqueuing members for approval')
              expect(response.payload[:members]).to match_array(members)
            end
          end
        end
      end
    end
  end

  describe '#execute' do
    context 'when source is group' do
      let(:source) { group }

      it_behaves_like 'promotion management feature'
    end

    context 'when source is project' do
      let(:source) { project }

      it_behaves_like 'promotion management feature'
    end
  end

  def add_non_billable_members
    users.each do |user|
      source.add_guest(user)
    end
  end

  def add_billable_members
    users.each do |user|
      source.add_developer(user)
      create(:user_highest_role, :developer, user: user)
    end
  end
end
