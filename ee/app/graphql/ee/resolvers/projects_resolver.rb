# frozen_string_literal: true

module EE
  module Resolvers
    module ProjectsResolver
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        argument :aimed_for_deletion, GraphQL::Types::Boolean,
          required: false,
          description: 'Return only projects marked for deletion.'
        argument :include_hidden, GraphQL::Types::Boolean,
          required: false,
          description: 'Include hidden projects.'
        argument :marked_for_deletion_on, ::Types::DateType,
          required: false,
          description: 'Date when the project was marked for deletion.'
      end

      private

      override :preloads
      def preloads
        super.merge(
          has_jira_vulnerability_issue_creation_enabled: [:jira_imports, :jira_integration],
          merge_requests_disable_committers_approval: [{ group: :group_merge_request_approval_setting }]
        )
      end

      override :finder_params
      def finder_params(args)
        super(args).merge(args.slice(:aimed_for_deletion, :include_hidden, :marked_for_deletion_on))
      end
    end
  end
end
