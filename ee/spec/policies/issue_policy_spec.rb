# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IssuePolicy, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:support_bot) { Users::Internal.support_bot }
  let_it_be(:project) { create(:project, :private) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:group) do
    create(:group, :public).tap do |g|
      g.add_reporter(reporter)
      g.add_owner(owner)
    end
  end

  let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }

  subject { described_class.new(user, issue) }

  before do
    allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
  end

  def permissions(user, issue)
    described_class.new(user, issue)
  end

  describe 'summarize_comments' do
    context "when feature is authorized" do
      before do
        allow(authorizer).to receive(:allowed?).and_return(true)
      end

      context 'when user can read issue' do
        before do
          project.add_guest(user)
        end

        it { is_expected.to be_allowed(:summarize_comments) }
      end

      context 'when user cannot read issue' do
        it { is_expected.to be_disallowed(:summarize_comments) }
      end
    end

    context "when feature is not authorized" do
      before do
        project.add_guest(user)
        allow(authorizer).to receive(:allowed?).and_return(false)
      end

      it { is_expected.to be_disallowed(:summarize_comments) }
    end
  end

  describe 'reopen_issue for group level issue' do
    let(:non_member) { user }

    let_it_be_with_reload(:group_issue) { create(:issue, :group_level, namespace: group) }

    it 'does not allow non members' do
      expect(permissions(non_member, group_issue)).to be_disallowed(:reopen_issue)
    end

    it 'allows it for members', :aggregate_failures do
      expect(permissions(guest, group_issue)).to be_disallowed(:reopen_issue)
      expect(permissions(reporter, group_issue)).to be_allowed(:reopen_issue)
      expect(permissions(owner, group_issue)).to be_allowed(:reopen_issue)
    end
  end

  describe 'admin_issue_relation' do
    let(:non_member) { user }
    let_it_be_with_reload(:group_issue) { create(:issue, :group_level, namespace: group) }
    let_it_be(:public_project) { create(:project, :public, group: group) }
    let_it_be(:private_project) { create(:project, :private, group: group) }
    let_it_be(:public_issue) { create(:issue, project: public_project) }
    let_it_be(:private_issue) { create(:issue, project: private_project) }

    before_all do
      group.add_guest(guest)
    end

    it 'does not allow non-members to admin_issue_relation' do
      expect(permissions(non_member, group_issue)).to be_disallowed(:admin_issue_relation)
      expect(permissions(non_member, private_issue)).to be_disallowed(:admin_issue_relation)
      expect(permissions(non_member, public_issue)).to be_disallowed(:admin_issue_relation)
    end

    it 'allow guest to admin_issue_relation' do
      expect(permissions(guest, group_issue)).to be_allowed(:admin_issue_relation)
      expect(permissions(guest, private_issue)).to be_allowed(:admin_issue_relation)
      expect(permissions(guest, public_issue)).to be_allowed(:admin_issue_relation)
    end

    context 'when issue is confidential' do
      let_it_be(:confidential_issue) { create(:issue, :confidential, project: public_project) }

      it 'does not allow guest to admin_issue_relation' do
        expect(permissions(guest, confidential_issue)).to be_disallowed(:admin_issue_relation)
      end

      it 'allow reporter to admin_issue_relation' do
        expect(permissions(reporter, confidential_issue)).to be_allowed(:admin_issue_relation)
      end
    end

    context 'when user is support bot and service desk is enabled' do
      before do
        allow(::Gitlab::Email::IncomingEmail).to receive(:enabled?).and_return(true)
        allow(::Gitlab::Email::IncomingEmail).to receive(:supports_wildcard?).and_return(true)
        allow_next_found_instance_of(Project) do |instance|
          allow(instance).to receive(:service_desk_enabled?).and_return(true)
        end
      end

      it 'allows support_bot to admin_issue_relation' do
        expect(permissions(support_bot, group_issue)).to be_allowed(:admin_issue_relation)
        expect(permissions(support_bot, public_issue)).to be_allowed(:admin_issue_relation)
        expect(permissions(support_bot, private_issue)).to be_allowed(:admin_issue_relation)
      end
    end

    context 'when user is support bot and service desk is disabled' do
      it 'does not allow support_bot to admin_issue_relation' do
        expect(permissions(support_bot, group_issue)).to be_disallowed(:admin_issue_relation)
        expect(permissions(support_bot, public_issue)).to be_disallowed(:admin_issue_relation)
        expect(permissions(support_bot, private_issue)).to be_disallowed(:admin_issue_relation)
      end
    end

    context 'when epic_relations_for_non_members feature flag is disabled' do
      before do
        stub_feature_flags(epic_relations_for_non_members: false)
      end

      it 'allows non-members to admin_issue_relation in public projects' do
        expect(permissions(non_member, public_issue)).to be_allowed(:admin_issue_relation)
      end

      it 'does not allow non-members to admin_issue_relation in private projects' do
        expect(permissions(non_member, private_issue)).to be_disallowed(:admin_issue_relation)
      end

      it 'allows guest to admin_issue_relation' do
        expect(permissions(guest, public_issue)).to be_allowed(:admin_issue_relation)
        expect(permissions(guest, private_issue)).to be_allowed(:admin_issue_relation)
      end
    end

    context 'when issue has a synced epic' do
      let_it_be_with_reload(:group_issue) { create(:issue, :with_synced_epic, namespace: group) }

      before do
        stub_licensed_features(issuable_resource_links: true)
        stub_feature_flags(synced_epic_work_item_editable: false)
      end

      it 'does allow' do
        # allows read permissions
        expect(permissions(reporter, group_issue)).to be_allowed(
          :read_cross_project, :read_issue, :read_incident_management_timeline_event, :read_issuable,
          :read_issuable_participables, :read_issuable_metric_image, :read_note, :read_internal_note,
          :read_work_item, :read_crm_contacts
        )
      end

      it 'does not allow' do
        # these read permissions are not yet allowed on group level issues
        expect(permissions(owner, group_issue)).to be_disallowed(
          :read_issuable_resource_link, :read_issue_iid, :read_design
        )

        # does not allow permissions that modify the issue
        expect(permissions(owner, group_issue)).to be_disallowed(
          :admin_issue, :update_issue, :set_issue_metadata, :create_note, :admin_issue_relation, :admin_issue_link,
          :award_emoji, :create_todo, :update_subscription, :create_requirement_test_report,
          :reopen_issue, :set_confidentiality, :set_issue_crm_contacts, :resolve_note, :admin_note,
          :set_note_created_at, :reposition_note, :mark_note_as_internal, :create_design, :update_design,
          :destroy_design, :move_design, :upload_issuable_metric_image, :update_issuable_metric_image,
          :destroy_issuable_metric_image, :admin_issuable_resource_link, :create_timelog, :admin_timelog,
          :destroy_issue, :admin_issue_metrics, :admin_issue_metrics_list
        )
      end

      context 'when editing epic work item is enabled' do
        before do
          stub_feature_flags(synced_epic_work_item_editable: true)
        end

        it 'does allow' do
          # allows some permissions as guest
          expect(permissions(guest, group_issue)).to be_allowed(
            :read_issue, :read_issuable, :admin_issue_link, :read_issuable_participables, :read_note, :read_work_item,
            :read_issuable_metric_image, :read_incident_management_timeline_event, :read_cross_project
          )

          # allows read permissions
          expect(permissions(reporter, group_issue)).to be_allowed(:read_internal_note, :read_crm_contacts)

          # allows some permissions that modify the issue
          expect(permissions(owner, group_issue)).to be_allowed(
            :admin_issue, :update_issue, :set_issue_metadata, :create_note, :admin_issue_relation, :award_emoji,
            :create_todo, :update_subscription, :set_confidentiality, :set_issue_crm_contacts, :set_note_created_at,
            :mark_note_as_internal, :create_timelog, :destroy_issue
          )
        end

        it 'does not allow' do
          # these read permissions are not yet defined for group level issues
          expect(permissions(owner, group_issue)).to be_disallowed(
            :read_issuable_resource_link, :read_issue_iid, :read_design
          )

          # these permissions are either not yet defined for group level issues or not allowed
          expect(permissions(owner, group_issue)).to be_disallowed(
            :create_requirement_test_report, :resolve_note, :admin_note,
            :reposition_note, :create_design, :update_design, :destroy_design, :move_design,
            :upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image,
            :admin_issuable_resource_link, :admin_timelog, :admin_issue_metrics, :admin_issue_metrics_list
          )
        end
      end
    end
  end
end
