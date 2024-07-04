# frozen_string_literal: true

module EE
  module MergeRequestsHelper
    extend ::Gitlab::Utils::Override

    def render_items_list(items, separator = "and")
      items_cnt = items.size

      case items_cnt
      when 1
        items.first
      when 2
        "#{items.first} #{separator} #{items.last}"
      else
        last_item = items.pop
        "#{items.join(", ")} #{separator} #{last_item}"
      end
    end

    override :diffs_tab_pane_data
    def diffs_tab_pane_data(project, merge_request, params)
      data = {
        endpoint_codequality: (codequality_mr_diff_reports_project_merge_request_path(project, merge_request, 'json') if project.licensed_feature_available?(:inline_codequality) && merge_request.has_codequality_mr_diff_report?),
        sast_report_available: merge_request.has_sast_reports?.to_s
      }

      data[:codequality_report_available] = merge_request.has_codequality_reports?.to_s if project.licensed_feature_available?(:inline_codequality)

      super.merge(data)
    end

    override :mr_compare_form_data
    def mr_compare_form_data(user, merge_request)
      target_branch_finder_path = if can?(user, :read_target_branch_rule, merge_request.project)
                                    project_target_branch_rules_path(merge_request.project)
                                  end

      super.merge({ target_branch_finder_path: target_branch_finder_path })
    end

    override :review_bar_data
    def review_bar_data(merge_request, user)
      super.merge({ can_summarize: Ability.allowed?(user, :summarize_draft_code_review, merge_request).to_s })
    end

    override :identity_verification_alert_data
    def identity_verification_alert_data(merge_request)
      {
        identity_verification_required: show_iv_alert_for_mr?(merge_request).to_s,
        identity_verification_path: identity_verification_path
      }
    end

    private

    def show_iv_alert_for_mr?(merge_request)
      return false unless current_user == merge_request.author

      !::Users::IdentityVerification::AuthorizeCi.new(user: current_user, project: merge_request.project).user_can_run_jobs?
    end
  end
end
