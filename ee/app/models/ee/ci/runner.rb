# frozen_string_literal: true

module EE
  module Ci
    module Runner
      extend ActiveSupport::Concern

      MOST_ACTIVE_RUNNERS_BUILDS_LIMIT = 1000

      prepended do
        has_one :cost_settings, class_name: 'Ci::Minutes::CostSetting', foreign_key: :runner_id, inverse_of: :runner

        scope :with_top_running_builds_of_runner_type, ->(runner_type) do
          most_active_runners(->(relation) { relation.where(runner_type: runner_type) })
        end

        scope :with_top_running_builds_by_namespace_id, ->(namespace_id) do
          most_active_runners(
            ->(relation) { relation.where(runner_type: :group_type).where(runner_owner_namespace_xid: namespace_id) }
          )
        end

        # NOTE: This scope is meant to be used with scopes that leverage the most_active_runners method
        scope :order_most_active_desc, -> do
          group(:id).reorder('COUNT(limited_builds.runner_id) DESC NULLS LAST', arel_table['id'].desc)
        end

        def self.any_shared_runners_with_enabled_cost_factor?(project)
          if project.public?
            instance_type.where('public_projects_minutes_cost_factor > 0').exists?
          else
            instance_type.where('private_projects_minutes_cost_factor > 0').exists?
          end
        end
      end

      def cost_factor_for_project(project)
        cost_factor.for_project(project)
      end

      def cost_factor_enabled?(project)
        cost_factor.enabled?(project)
      end

      def matches_build?(build)
        return false unless super(build)

        allowed_for_plans?(build)
      end

      def allowed_for_plans?(build)
        return true unless ::Feature.enabled?(:ci_runner_separation_by_plan, self, type: :ops)
        return true if allowed_plans.empty?

        plans = build.namespace&.plans || []

        common = allowed_plans & plans.map(&:name)
        common.any?
      end

      private

      def cost_factor
        strong_memoize(:cost_factor) do
          ::Gitlab::Ci::Minutes::CostFactor.new(runner_matcher)
        end
      end

      class_methods do
        def most_active_runners(inner_query_fn = nil)
          inner_query = ::Ci::RunningBuild.select(
            'runner_id',
            Arel.sql('ROW_NUMBER() OVER (PARTITION BY runner_id ORDER BY runner_id) AS rn')
          )
          inner_query = inner_query_fn.call(inner_query) if inner_query_fn

          joins(
            <<~SQL
            INNER JOIN (#{inner_query.to_sql}) AS "limited_builds" ON "limited_builds"."runner_id" = "ci_runners"."id"
                                               AND "limited_builds".rn <= #{MOST_ACTIVE_RUNNERS_BUILDS_LIMIT}
            SQL
          )
        end
      end
    end
  end
end
