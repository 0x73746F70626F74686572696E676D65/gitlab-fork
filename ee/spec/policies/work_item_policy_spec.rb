# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItemPolicy, feature_category: :team_planning do
  let_it_be(:guest) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:group) do
    create(:group, :public).tap do |g|
      g.add_guest(guest)
      g.add_reporter(reporter)
      g.add_owner(owner)
    end
  end

  def permissions(user, work_item)
    described_class.new(user, work_item)
  end

  context 'when work item has a synced epic' do
    let_it_be_with_reload(:work_item) { create(:epic, :with_synced_work_item, group: group).work_item }

    before do
      stub_licensed_features(issuable_resource_links: true)
      stub_feature_flags(synced_epic_work_item_editable: false)
    end

    it 'does allow' do
      # allows read permissions
      expect(permissions(reporter, work_item)).to be_allowed(
        :read_cross_project, :read_issue, :read_incident_management_timeline_event, :read_issuable,
        :read_issuable_participables, :read_issuable_metric_image, :read_note, :read_internal_note,
        :read_work_item, :read_crm_contacts
      )
    end

    it 'does not allow' do
      # these read permissions are not yet allowed on group level issues
      expect(permissions(owner, work_item)).to be_disallowed(
        :read_issuable_resource_link, :read_issue_iid, :read_design
      )

      # does not allow permissions that modify the issue
      expect(permissions(owner, work_item)).to be_disallowed(
        :admin_issue, :update_issue, :set_issue_metadata, :create_note, :admin_issue_relation, :admin_issue_link,
        :award_emoji, :create_todo, :update_subscription, :create_requirement_test_report,
        :reopen_issue, :set_confidentiality, :set_issue_crm_contacts, :resolve_note, :admin_note,
        :set_note_created_at, :reposition_note, :mark_note_as_internal, :create_design, :update_design,
        :destroy_design, :move_design, :upload_issuable_metric_image, :update_issuable_metric_image,
        :destroy_issuable_metric_image, :admin_issuable_resource_link, :create_timelog, :admin_timelog,
        :destroy_issue, :admin_issue_metrics, :admin_issue_metrics_list
      )
    end

    context 'when synced_epic_work_item_editable is enabled' do
      before do
        stub_feature_flags(synced_epic_work_item_editable: true)
      end

      it 'does allow' do
        # allows read permissions for guest users
        expect(permissions(guest, work_item)).to be_allowed(
          :read_cross_project, :read_issue, :read_incident_management_timeline_event, :read_issuable,
          :read_issuable_participables, :read_issuable_metric_image, :read_note, :read_work_item
        )

        # allows read permissions
        expect(permissions(reporter, work_item)).to be_allowed(:read_internal_note, :read_crm_contacts, :reopen_issue)

        # allows some permissions that modify the issue
        expect(permissions(owner, work_item)).to be_allowed(
          :admin_issue, :update_issue, :set_issue_metadata, :create_note, :admin_issue_relation, :award_emoji,
          :create_todo, :update_subscription, :set_confidentiality, :set_issue_crm_contacts, :set_note_created_at,
          :mark_note_as_internal, :create_timelog, :destroy_issue
        )
      end

      it 'does not allow' do
        # these read permissions are not yet defined for group level issues
        expect(permissions(owner, work_item)).to be_disallowed(
          :read_issuable_resource_link, :read_issue_iid, :read_design
        )

        # these permissions are either not yet defined for group level issues or not allowed
        expect(permissions(owner, work_item)).to be_disallowed(
          :create_requirement_test_report, :resolve_note, :admin_note,
          :reposition_note, :create_design, :update_design, :destroy_design, :move_design,
          :upload_issuable_metric_image, :update_issuable_metric_image, :destroy_issuable_metric_image,
          :admin_issuable_resource_link, :admin_timelog, :admin_issue_metrics, :admin_issue_metrics_list
        )
      end

      context 'when related_epics feature is available' do
        before do
          stub_licensed_features(related_epics: true)
        end

        it 'allow linking of epic work items' do
          expect(permissions(guest, work_item)).to be_allowed(
            :admin_work_item_link
          )
        end
      end

      context 'when related_epics feature is not available' do
        before do
          stub_licensed_features(related_epics: false)
        end

        it 'does not allow linking of epic work items' do
          expect(permissions(guest, work_item)).to be_disallowed(
            :admin_work_item_link
          )
        end
      end
    end
  end
end
