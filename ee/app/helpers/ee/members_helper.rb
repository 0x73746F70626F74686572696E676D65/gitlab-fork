# frozen_string_literal: true

module EE
  module MembersHelper
    def members_page?
      current_path?('groups/group_members#index') ||
        current_path?('projects/project_members#index')
    end

    private

    def promotion_pending_members_list_data(pending_promotion_members)
      pagination = { param_name: :promotion_requests_page, params: { page: nil } }
      {
        data: promotion_pending_members_serialized(pending_promotion_members),
        pagination: members_pagination_data(pending_promotion_members, pagination)
      }
    end

    def promotion_pending_members_serialized(pending_promotion_members)
      GitlabSubscriptions::MemberManagement::MemberApprovalSerializer.new.represent(
        pending_promotion_members, { current_user: current_user }
      )
    end

    def member_header_manage_namespace_members_text(namespace)
      manage_text = _(
        'To manage seats for all members associated with this group and its subgroups and projects, ' \
        'visit the %{link_start}usage quotas page%{link_end}.'
      ).html_safe % {
        link_start: "<a href='#{group_usage_quotas_path(namespace)}'>".html_safe,
        link_end: '</a>'.html_safe
      }

      "<br />".html_safe + manage_text
    end
  end
end
