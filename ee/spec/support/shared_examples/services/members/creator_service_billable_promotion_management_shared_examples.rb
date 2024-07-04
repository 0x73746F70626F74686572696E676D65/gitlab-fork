# frozen_string_literal: true

RSpec.shared_examples 'billable promotion management feature' do
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:actor) { create(:user) }
  let(:access_level) { :developer }

  before do
    source.add_owner(actor)

    stub_feature_flags(member_promotion_management: true)
    stub_application_setting(enable_member_promotion_management: true)
    allow(License).to receive(:current).and_return(license)
  end

  subject(:add_member) do
    described_class.add_member(source, user, access_level, current_user: actor)
  end

  shared_examples 'adds the member' do
    it 'adds the member' do
      expect { add_member }.to change { Member.count }.by(1)
    end
  end

  context 'on self managed' do
    context 'when feature is not applicable' do
      let(:existing_member) { nil }

      context 'when license is not ultimate' do
        let(:license) { create(:license, plan: License::PREMIUM_PLAN) }

        it_behaves_like 'adds the member'
      end

      context 'when feature flag is disabled' do
        before do
          stub_feature_flags(member_promotion_management: false)
        end

        it_behaves_like 'adds the member'
      end

      context 'when setting is disabled' do
        before do
          stub_application_setting(enable_member_promotion_management: false)
        end

        it_behaves_like 'adds the member'
      end
    end

    shared_examples 'it queues the request' do
      it 'queues the member' do
        member = nil
        expect do
          member = add_member
        end.to change { Members::MemberApproval.count }.by(1)

        expect(member.errors[:base].first).to eq("Request Queued For Admin Approval.")
      end
    end

    shared_examples 'returns errored member when queuing fails' do
      before do
        allow(Members::MemberApproval).to receive(:create_or_update_pending_approval)
                                            .and_raise(ActiveRecord::RecordInvalid)
      end

      it 'returns errored members' do
        member = nil
        expect do
          member = add_member
        end.not_to change { Members::MemberApproval.count }

        expect(member.errors[:base].first).to eq("Invalid record while queuing users for approval.")
      end
    end

    context 'with new user' do
      let(:existing_member) { nil }

      context 'when trying to add billable member' do
        it_behaves_like 'it queues the request'

        it_behaves_like 'returns errored member when queuing fails'
      end

      context 'when trying to add a non billable member' do
        let(:access_level) { :guest }

        it_behaves_like 'adds the member'
      end
    end

    context 'with existing member' do
      shared_examples "updates the members" do
        it 'updates the member' do
          expect { add_member }.not_to change { Members::MemberApproval.count }
          expect(existing_member.reload.access_level).to eq(Gitlab::Access.sym_options_with_owner[access_level])
        end
      end

      context 'when trying to change to a billable role' do
        let(:access_level) { :maintainer }

        context 'when user is non billable' do
          let(:existing_role) { :guest }

          it_behaves_like 'it queues the request'

          it_behaves_like 'returns errored member when queuing fails'
        end

        context 'when user is billable' do
          let(:existing_role) { :developer }

          it_behaves_like 'updates the members'
        end
      end

      context 'when trying to change to a non billable role' do
        let(:access_level) { :guest }

        context 'when user is billable' do
          let(:existing_role) { :maintainer }

          it_behaves_like 'updates the members'
        end
      end
    end
  end

  context 'on saas', :saas do
    let(:existing_member) { nil }

    it_behaves_like 'adds the member'
  end
end

RSpec.shared_examples 'billable promotion management for multiple users' do
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:actor) { create(:user) }
  let(:access_level) { :developer }

  before do
    source.add_owner(actor)

    stub_feature_flags(member_promotion_management: true)
    stub_application_setting(enable_member_promotion_management: true)
    allow(License).to receive(:current).and_return(license)
  end

  subject(:add_members) do
    described_class.add_members(source, users, access_level, current_user: actor)
  end

  context 'with multiple users' do
    let(:another_user) { create(:user) }
    let(:users) { [another_user.id, user.id] }

    context 'with one billable and one non billable' do
      before do
        source.add_guest(another_user)
      end

      let(:existing_role) { :developer }
      let(:access_level) { :maintainer }

      it 'updates billable member and queues non billable member' do
        members = nil

        expect do
          members = add_members
        end.to change { Members::MemberApproval.count }.by(1)

        expect(members.first.errors[:base].first).to eq("Request Queued For Admin Approval.")
        expect(members.second.access_level).to eq(Gitlab::Access.sym_options_with_owner[access_level])
        expect(members.second.errors[:base]).to be_empty
      end
    end

    context 'with both billable' do
      let(:existing_role) { :developer }
      let(:access_level) { :maintainer }

      before do
        source.add_developer(another_user)
      end

      it 'updates both members' do
        members = nil

        expect do
          members = add_members
        end.not_to change { Members::MemberApproval.count }

        expect(members.first.access_level).to eq(Gitlab::Access.sym_options_with_owner[access_level])
        expect(members.first.errors[:base]).to be_empty
        expect(members.second.access_level).to eq(Gitlab::Access.sym_options_with_owner[access_level])
        expect(members.second.errors[:base]).to be_empty
      end
    end

    context 'with both non billable' do
      let(:existing_role) { :guest }
      let(:access_level) { :maintainer }

      before do
        source.add_guest(another_user)
      end

      it 'queues both members' do
        members = nil

        expect do
          members = add_members
        end.to change { Members::MemberApproval.count }.by(2)

        expect(members.first.errors[:base].first).to eq("Request Queued For Admin Approval.")
        expect(members.second.errors[:base].first).to eq("Request Queued For Admin Approval.")
      end
    end
  end
end
