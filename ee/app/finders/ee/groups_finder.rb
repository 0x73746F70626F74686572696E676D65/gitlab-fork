# frozen_string_literal: true

module EE
  module GroupsFinder
    extend ::Gitlab::Utils::Override

    private

    override :filter_groups
    def filter_groups(groups)
      groups = super(groups)
      groups = by_marked_for_deletion_on(groups)
      by_repository_storage(groups)
    end

    def by_repository_storage(groups)
      return groups if params[:repository_storage].blank?

      groups.by_repository_storage(params[:repository_storage])
    end

    def by_marked_for_deletion_on(groups)
      return groups unless params[:marked_for_deletion_on].present?
      return groups unless License.feature_available?(:adjourned_deletion_for_projects_and_groups)

      groups.by_marked_for_deletion_on(params[:marked_for_deletion_on])
    end
  end
end
