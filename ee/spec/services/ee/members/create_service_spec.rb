# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::CreateService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:root_ancestor, reload: true) { create(:group) }
  let_it_be(:project, reload: true) { create(:project, group: root_ancestor) }
  let_it_be(:subgroup) { create(:group, parent: root_ancestor) }
  let_it_be(:subgroup_project) { create(:project, group: subgroup) }
  let_it_be(:project_users) { create_list(:user, 2) }

  let(:invites) { project_users.map(&:id).join(',') }
  let(:params) do
    {
      user_id: invites,
      access_level: Gitlab::Access::GUEST,
      invite_source: '_invite_source_'
    }
  end

  subject(:execute_service) { described_class.new(user, params.merge({ source: project })).execute }

  before_all do
    project.add_maintainer(user)

    create(:project_member, :invited, project: subgroup_project, created_at: 2.days.ago)
    create(:project_member, :invited, project: subgroup_project)
    create(:group_member, :invited, group: subgroup, created_at: 2.days.ago)
    create(:group_member, :invited, group: subgroup)
  end

  context 'with group plan observing quota limits', :saas do
    let(:plan_limits) { create(:plan_limits, daily_invites: daily_invites) }
    let(:plan) { create(:plan, limits: plan_limits) }
    let!(:subscription) do
      create(
        :gitlab_subscription,
        namespace: root_ancestor,
        hosted_plan: plan
      )
    end

    shared_examples 'quota limit exceeded' do |limit|
      it { expect(execute_service).to include(status: :error, message: "Invite limit of #{limit} per day exceeded.") }
      it { expect { execute_service }.not_to change { Member.count } }
    end

    context 'already exceeded invite quota limit' do
      let(:daily_invites) { 2 }

      it_behaves_like 'quota limit exceeded', 2
    end

    context 'will exceed invite quota limit' do
      let(:daily_invites) { 3 }

      it_behaves_like 'quota limit exceeded', 3
    end

    context 'within invite quota limit' do
      let(:daily_invites) { 5 }

      it { expect(execute_service).to eq({ status: :success }) }

      it do
        execute_service

        expect(project.users).to include(*project_users)
      end
    end

    context 'infinite invite quota limit' do
      let(:daily_invites) { 0 }

      it { expect(subject).to eq({ status: :success }) }

      it do
        execute_service

        expect(project.users).to include(*project_users)
      end
    end
  end

  context 'without a plan' do
    let(:plan) { nil }

    it { expect(execute_service).to eq({ status: :success }) }

    it do
      execute_service

      expect(project.users).to include(*project_users)
    end
  end

  context 'streaming audit event' do
    let(:group) { root_ancestor }
    let(:params) do
      {
        user_id: project_users.first.id,
        access_level: Gitlab::Access::GUEST,
        invite_source: '_invite_source_'
      }
    end

    it 'audits event with name' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(name: "member_created")
      ).and_call_original

      subject
    end

    include_examples 'sends streaming audit event'
  end

  context 'with seat availability concerns', :saas do
    let_it_be(:root_ancestor) { create(:group_with_plan, :private, plan: :free_plan) }
    let_it_be(:project) { create(:project, group: root_ancestor) }

    before do
      project.add_maintainer(user)
      stub_ee_application_setting(dashboard_limit_enabled: true)
    end

    context 'when creating' do
      context 'when seat is available' do
        before do
          stub_ee_application_setting(dashboard_limit: 3)
        end

        context 'with existing user that is a member in our hierarchy' do
          let(:existing_user) do
            new_project = create(:project, group: root_ancestor)
            create(:project_member, project: new_project).user
          end

          let(:invites) { "#{create(:user).id},#{existing_user.id}" }

          it 'adds the member' do
            expect(execute_service[:status]).to eq(:success)
            expect(project.users).to include existing_user
          end
        end

        context 'when under the dashboard limit' do
          it 'adds the members' do
            expect(execute_service[:status]).to eq(:success)
            expect(project.users).to include(*project_users)
          end
        end
      end

      context 'when seat is not available' do
        it 'does not add members' do
          expect(execute_service[:status]).to eq(:error)
          expect(execute_service[:message]).to match /: cannot be added since you've reached your /
          expect(project.users).not_to include(*project_users)
        end
      end
    end

    context 'when updating with no seats left' do
      let(:invites) { invited_member.invite_email }
      let(:invited_member) do
        build(:project_member, :maintainer, :invited, source: project).tap do |record|
          record.member_namespace_id = record.project.project_namespace_id
          record.save!(validate: false)
        end
      end

      before do
        stub_ee_application_setting(dashboard_limit: 1)
      end

      it 'allows updating existing invited member' do
        expect(execute_service[:status]).to eq(:success)
        expect(invited_member.reset.access_level).to eq Gitlab::Access::GUEST
      end
    end
  end

  context 'when part of a group that a free group invited', :saas, :sidekiq_inline do
    context 'when free group is over the limit' do
      let(:dashboard_limit_enabled) { true }
      let_it_be(:owner) { create(:user) }
      let_it_be(:root_ancestor) do
        create(:group_with_plan, :private, plan: :free_plan, owners: owner)
      end

      let_it_be(:invited_group) do
        create(:group).tap do |g|
          g.add_owner(user)
          create(:group_group_link, { shared_with_group: g, shared_group: root_ancestor })
        end
      end

      before do
        stub_ee_application_setting(dashboard_limit: 3)
        stub_ee_application_setting(dashboard_limit_enabled: dashboard_limit_enabled)
        stub_feature_flags(block_seat_overages: false)
      end

      subject(:execute_service) { described_class.new(user, params.merge({ source: invited_group })).execute }

      it 'triggers an email notification to owners' do
        root_ancestor.all_owner_members.preload_users.find_each do |member|
          expect(::Namespaces::FreeUserCapMailer)
            .to receive(:over_limit_email).with(member.user, root_ancestor).once.and_call_original
        end

        execute_service
      end

      shared_examples 'notification does not get triggered' do
        it 'does not trigger the notification worker' do
          expect(::Namespaces::FreeUserCap::GroupOverLimitNotificationWorker).not_to receive(:perform_async)

          execute_service
        end
      end

      context 'when member source is not a Group' do
        subject(:execute_service) { described_class.new(user, params.merge({ source: project })).execute }

        it_behaves_like 'notification does not get triggered'
      end

      context 'when dashboard limit is not enabled' do
        let(:dashboard_limit_enabled) { false }

        it_behaves_like 'notification does not get triggered'
      end

      context 'when all members added already existed' do
        let(:invites) { [owner.id] }

        before_all do
          invited_group.add_developer(owner)
        end

        it_behaves_like 'notification does not get triggered'
      end

      context 'when all members added are not associated with a user' do
        let(:invites) { ['email@example.org'] }

        it_behaves_like 'notification does not get triggered'
      end
    end
  end

  context 'when group membership is locked' do
    before do
      root_ancestor.update_attribute(:membership_lock, true)
    end

    it 'does not add the given users to the team' do
      expect { execute_service }.not_to change { project.members.count }
    end
  end

  context 'when assigning a member role' do
    let_it_be(:member_role) { create(:member_role, :guest, namespace: root_ancestor) }

    before do
      params[:member_role_id] = member_role.id
    end

    context 'with custom_roles feature' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      it 'adds a user to members with custom role assigned' do
        expect { execute_service }.to change { project.members.count }.by(2)

        member = Member.last

        expect(member.member_role).to eq(member_role)
        expect(member.access_level).to eq(Member::GUEST)
      end
    end

    context 'without custom_roles feature' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it 'adds a user to members without custom role assigned' do
        expect { execute_service }.to change { project.members.count }.by(2)

        member = Member.last

        expect(member.member_role).to be_nil
        expect(member.access_level).to eq(Member::GUEST)
      end
    end
  end

  context 'with block seat overages enabled', :saas do
    let_it_be(:owner) { create(:user) }
    let_it_be(:user) { create(:user) }
    let_it_be(:group) do
      create(:group_with_plan, plan: :premium_plan).tap { |g| g.add_owner(owner) }
    end

    let_it_be(:project) { create(:project, group: group) }

    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      stub_feature_flags(block_seat_overages: true)
      group.gitlab_subscription.update!(seats: 1)
    end

    it 'notifies the admin about the requested membership' do
      expect(::Notify).to receive(:no_more_seats)
        .with(owner.id, user.id, project, project_users.map(&:name)).once.and_call_original

      execute_service
    end

    context 'with invited emails' do
      let(:invites) { ['email@example.com'] }

      it 'removes invite emails from the seat check' do
        expect(::Notify).not_to receive(:no_more_seats).and_call_original

        execute_service
      end
    end
  end
end
