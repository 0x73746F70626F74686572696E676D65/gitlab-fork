# frozen_string_literal: true

module Import
  class SourceUserPolicy < ::BasePolicy
    condition(:admin_source_user_namespace) { can?(:admin_namespace, @subject.namespace) }
    desc "User can administrate namespace"

    rule { admin_source_user_namespace }.policy do
      enable :admin_import_source_user
    end
  end
end
