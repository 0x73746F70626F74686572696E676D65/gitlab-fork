# frozen_string_literal: true

# NOTE: The patterns first introduced in this helper for doing trial-related
# callouts are mimicked by the PaidFeatureCalloutHelper. A third reuse of these
# patterns (especially as these experiments finish & become permanent parts of
# the codebase) could trigger the need to extract these patterns into a single,
# reusable, sharable helper.
module TrialStatusWidgetHelper
  CONTAINER_ID = 'trial-status-sidebar-widget'

  def trial_status_popover_data_attrs(trial_status)
    {
      days_remaining: trial_status.days_remaining,
      target_id: CONTAINER_ID,
      trial_end_date: trial_status.ends_on
    }
  end

  def trial_status_widget_data_attrs(group, trial_status)
    trial_status_common_data_attrs(group).merge(
      trial_days_used: trial_status.days_used,
      trial_duration: trial_status.duration,
      nav_icon_image_path: image_path('illustrations/gitlab_logo.svg'),
      percentage_complete: trial_status.percentage_complete
    )
  end

  def show_trial_status_widget?(group)
    return true if group.trial_active?

    !group.paid? && group.trial_ends_on && group.trial_ends_on > 10.days.ago
  end

  private

  def trial_status_common_data_attrs(group)
    {
      container_id: CONTAINER_ID,
      plan_name: group.gitlab_subscription.plan_title,
      plans_href: group_billings_path(group),
      trial_discover_page_path: group_discover_path(group)
    }
  end
end

TrialStatusWidgetHelper.prepend_mod
