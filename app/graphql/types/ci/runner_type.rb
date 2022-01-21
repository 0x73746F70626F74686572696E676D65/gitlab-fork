# frozen_string_literal: true

module Types
  module Ci
    class RunnerType < BaseObject
      edge_type_class(RunnerWebUrlEdge)
      connection_type_class(Types::CountableConnectionType)
      graphql_name 'CiRunner'
      authorize :read_runner
      present_using ::Ci::RunnerPresenter

      expose_permissions Types::PermissionTypes::Ci::Runner

      JOB_COUNT_LIMIT = 1000

      alias_method :runner, :object

      field :id, ::Types::GlobalIDType[::Ci::Runner], null: false,
            description: 'ID of the runner.'
      field :description, GraphQL::Types::String, null: true,
            description: 'Description of the runner.'
      field :created_at, Types::TimeType, null: true,
            description: 'Timestamp of creation of this runner.'
      field :contacted_at, Types::TimeType, null: true,
            description: 'Timestamp of last contact from this runner.',
            method: :contacted_at
      field :maximum_timeout, GraphQL::Types::Int, null: true,
            description: 'Maximum timeout (in seconds) for jobs processed by the runner.'
      field :access_level, ::Types::Ci::RunnerAccessLevelEnum, null: false,
            description: 'Access level of the runner.'
      field :active, GraphQL::Types::Boolean, null: false,
            description: 'Indicates the runner is allowed to receive jobs.'
      field :status,
            Types::Ci::RunnerStatusEnum,
            null: false,
            description: 'Status of the runner.',
            resolver: ::Resolvers::Ci::RunnerStatusResolver
      field :version, GraphQL::Types::String, null: true,
            description: 'Version of the runner.'
      field :short_sha, GraphQL::Types::String, null: true,
            description: %q(First eight characters of the runner's token used to authenticate new job requests. Used as the runner's unique ID.)
      field :revision, GraphQL::Types::String, null: true,
            description: 'Revision of the runner.'
      field :locked, GraphQL::Types::Boolean, null: true,
            description: 'Indicates the runner is locked.'
      field :run_untagged, GraphQL::Types::Boolean, null: false,
            description: 'Indicates the runner is able to run untagged jobs.'
      field :ip_address, GraphQL::Types::String, null: true,
            description: 'IP address of the runner.'
      field :runner_type, ::Types::Ci::RunnerTypeEnum, null: false,
            description: 'Type of the runner.'
      field :tag_list, [GraphQL::Types::String], null: true,
            description: 'Tags associated with the runner.'
      field :project_count, GraphQL::Types::Int, null: true,
            description: 'Number of projects that the runner is associated with.'
      field :job_count, GraphQL::Types::Int, null: true,
            description: "Number of jobs processed by the runner (limited to #{JOB_COUNT_LIMIT}, plus one to indicate that more items exist)."
      field :admin_url, GraphQL::Types::String, null: true,
            description: 'Admin URL of the runner. Only available for administrators.'
      field :edit_admin_url, GraphQL::Types::String, null: true,
            description: 'Admin form URL of the runner. Only available for administrators.'
      field :executor_name, GraphQL::Types::String, null: true,
            description: 'Executor last advertised by the runner.',
            method: :executor_name,
            feature_flag: :graphql_ci_runner_executor
      field :groups, ::Types::GroupType.connection_type, null: true,
            description: 'Groups the runner is associated with. For group runners only.'
      field :projects, ::Types::ProjectType.connection_type, null: true,
            description: 'Projects the runner is associated with. For project runners only.'

      def job_count
        # We limit to 1 above the JOB_COUNT_LIMIT to indicate that more items exist after JOB_COUNT_LIMIT
        runner.builds.limit(JOB_COUNT_LIMIT + 1).count
      end

      def admin_url
        Gitlab::Routing.url_helpers.admin_runner_url(runner) if can_admin_runners?
      end

      def edit_admin_url
        Gitlab::Routing.url_helpers.edit_admin_runner_url(runner) if can_admin_runners?
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def project_count
        BatchLoader::GraphQL.for(runner.id).batch(key: :runner_project_count) do |ids, loader, args|
          counts = ::Ci::Runner.project_type
            .select(:id, 'COUNT(ci_runner_projects.id) as count')
            .left_outer_joins(:runner_projects)
            .where(id: ids)
            .group(:id)
            .index_by(&:id)

          ids.each do |id|
            loader.call(id, counts[id]&.count)
          end
        end
      end

      def groups
        BatchLoader::GraphQL.for(runner.id).batch(key: :runner_groups) do |runner_ids, loader, args|
          runner_and_namespace_ids =
            ::Ci::RunnerNamespace
              .where(runner_id: runner_ids)
              .pluck(:runner_id, :namespace_id)

          group_ids_by_runner_id = runner_and_namespace_ids.group_by(&:first).transform_values { |v| v.pluck(1) }
          group_ids = runner_and_namespace_ids.pluck(1).uniq

          groups = Group.where(id: group_ids).index_by(&:id)

          runner_ids.each do |runner_id|
            loader.call(runner_id, group_ids_by_runner_id[runner_id]&.map { |group_id| groups[group_id] })
          end
        end
      end

      def projects
        return unless runner.project_type?

        BatchLoader::GraphQL.for(runner.id).batch(key: :runner_projects) do |runner_ids, loader, args|
          runner_and_project_ids =
            ::Ci::RunnerProject
              .where(runner_id: runner_ids)
              .pluck(:runner_id, :project_id)

          project_ids_by_runner_id = runner_and_project_ids.group_by(&:first).transform_values { |v| v.pluck(1) }
          project_ids = runner_and_project_ids.pluck(1).uniq

          projects = Project.where(id: project_ids).index_by(&:id)

          runner_ids.each do |runner_id|
            loader.call(runner_id, project_ids_by_runner_id[runner_id]&.map { |project_id| projects[project_id] } || [])
          end
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord

      private

      def can_admin_runners?
        context[:current_user]&.can_admin_all_resources?
      end
    end
  end
end

Types::Ci::RunnerType.prepend_mod_with('Types::Ci::RunnerType')
