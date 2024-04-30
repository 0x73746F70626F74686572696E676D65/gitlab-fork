# frozen_string_literal: true

module EE
  module API
    module Helpers
      module NotesHelpers
        extend ActiveSupport::Concern

        class_methods do
          extend ::Gitlab::Utils::Override

          override :feature_category_per_noteable_type
          def feature_category_per_noteable_type
            super.merge!(
              ::Epic => :portfolio_management,
              ::Vulnerability => :vulnerability_management
            )
          end
        end

        def add_parent_to_finder_params(finder_params, noteable_type)
          if noteable_type.name.underscore == 'epic'
            finder_params[:group_id] = user_group.id
          else
            super
          end
        end

        # private projects can be found as long as user is a project member.
        # internal projects can be found by any authenticated user.
        def find_merge_request(merge_request_iid)
          params = finder_params_by_noteable_type_and_id(::MergeRequest, merge_request_iid)

          ::NotesFinder.new(current_user, params).target || not_found!(::MergeRequest)
        end
      end
    end
  end
end
