# frozen_string_literal: true

class Groups::AuditEventsController < Groups::ApplicationController
  include Gitlab::Utils::StrongMemoize
  include AuditEvents::EnforcesValidDateParams
  include AuditEvents::AuditEventsParams
  include AuditEvents::Sortable
  include AuditEvents::DateRange
  include ProductAnalyticsTracking
  include GovernUsageGroupTracking

  before_action :check_audit_events_available!

  BATCH_SIZE = 100

  track_event :index,
    name: 'g_compliance_audit_events',
    action: 'visit_group_compliance_audit_events',
    label: 'redis_hll_counters.compliance.compliance_total_unique_counts_monthly',
    destinations: [:redis_hll, :snowplow]

  track_govern_activity 'audit_events', :index

  feature_category :audit_events

  urgency :low

  def index
    @is_last_page = events.last_page?
    @events = AuditEventSerializer.new.represent(events)
    @audit_event_definitions = Gitlab::Audit::Type::Definition.names_with_category

    Gitlab::Tracking.event(self.class.name, 'search_audit_event', user: current_user, namespace: group)
  end

  private

  def check_audit_events_available!
    render_404 unless can?(current_user, :read_group_audit_events, group) &&
      group.licensed_feature_available?(:audit_events)
  end

  def events
    strong_memoize(:events) do
      level = Gitlab::Audit::Levels::Group.new(group: group)
      events = AuditEventFinder
        .new(level: level, params: audit_params)
        .execute
        .page(pagination_params[:page])
        .without_count

      Gitlab::Audit::Events::Preloader.preload!(events)
    end
  end

  def can_view_events_from_all_members?(user)
    can?(user, :admin_group, group) || user.auditor?
  end

  def tracking_namespace_source
    group
  end

  def tracking_project_source
    nil
  end
end
