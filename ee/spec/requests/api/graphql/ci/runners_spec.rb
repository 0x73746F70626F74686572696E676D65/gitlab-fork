# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'Query.runners', feature_category: :fleet_visibility do
  include GraphqlHelpers
  include RunnerReleasesHelper

  let_it_be(:current_user) { create_default(:user, :admin) }

  describe 'Query.runners' do
    let_it_be(:project) { create(:project, :repository, :public) }
    let_it_be(:instance_runner) { create(:ci_runner, :instance, version: '14.0.0') }
    let_it_be(:project_runner) { create(:ci_runner, :project, version: '14.0.1', projects: [project]) }

    let(:runners_graphql_data) { graphql_data['runners'] }
    let(:params) { {} }
    let(:runner_upgrade_management) { false }

    before do
      stub_runner_releases(%w[14.0.0 14.0.1])
    end

    context 'with upgradeStatus argument' do
      let(:upgrade_statuses) { runners_graphql_data['nodes'].map { |n| n['upgradeStatus'] } }
      let(:query) do
        %(
           query getRunners($upgradeStatus: #{upgrade_status_graphql_type}) {
             runners(upgradeStatus: $upgradeStatus) {
               nodes {
                 id
                 upgradeStatus
               }
             }
           }
         )
      end

      before do
        post_graphql(query, current_user: current_user)
      end

      context 'with new CiRunnerUpgradeStatus enum type' do
        let(:upgrade_status_graphql_type) { 'CiRunnerUpgradeStatus' }

        it 'returns nil upgradeStatus for all runners' do
          expect(upgrade_statuses).to match_array([nil] * Ci::Runner.count)
        end
      end
    end

    context 'with membership argument' do
      let_it_be(:group) { create(:group) }
      let_it_be(:sub_group) { create(:group, parent: group) }
      let_it_be(:group_runner) { create(:ci_runner, :group, groups: [group]) }
      let_it_be(:sub_group_runner) { create(:ci_runner, :group, groups: [sub_group]) }

      let(:actual_runner_ids) { graphql_data_at(:group, :runners, :nodes).map { |n| n['id'] } }
      let(:expected_runner_ids) { [group_runner, sub_group_runner].map { |g| g.to_global_id.to_s } }
      let(:query) do
        %(
           query getGroupRunners($membership: CiRunnerMembershipFilter) {
             group(fullPath: "#{group.full_path}") {
               runners(membership: $membership) {
                 nodes {
                   id
                 }
               }
             }
           }
         )
      end

      before do
        post_graphql(query, current_user: current_user)
      end

      it { expect(actual_runner_ids).to match_array(expected_runner_ids) }
    end

    context 'when sorting by MOST_ACTIVE_DESC' do
      let_it_be(:instance_runners) { create_list(:ci_runner, 6) }
      let_it_be(:group) { create(:group) }
      let_it_be(:group_runners) { create_list(:ci_runner, 3, :group, groups: [group]) }

      let(:args) { { type: :INSTANCE_TYPE, sort: :MOST_ACTIVE_DESC } }
      let(:query) { graphql_query_for(:runners, args, 'nodes { id }') }

      subject(:request) { post_graphql(query, current_user: current_user) }

      before_all do
        instance_runners.map.with_index do |runner, number_of_builds|
          create_list(:ci_build, number_of_builds, :picked, runner: runner, project: project)
        end

        group_runners.map.with_index do |runner, number_of_builds|
          create_list(:ci_build, 3 + number_of_builds, :picked, runner: runner, project: project)
        end
      end

      context 'when runner_performance_insights feature is available' do
        using RSpec::Parameterized::TableSyntax

        before do
          stub_licensed_features(runner_performance_insights: true)
        end

        it_behaves_like 'sorted paginated query' do
          def pagination_query(params)
            graphql_query_for(:runners, params.merge(type: :INSTANCE_TYPE), "#{page_info} nodes { id }")
          end

          def pagination_results_data(runners)
            runners.map { |runner| GitlabSchema.parse_gid(runner['id'], expected_type: ::Ci::Runner).model_id.to_i }
          end

          let(:sort_param) { :MOST_ACTIVE_DESC }
          let(:first_param) { 2 }
          let(:all_records) { instance_runners[1..5].reverse.map(&:id) }
          let(:data_path) { [:runners] }
        end

        context 'when requesting group runners' do
          let(:query) do
            graphql_query_for(:group, { full_path: group.full_path }, query_nodes(:runners, :id, args: args))
          end

          context 'with direct membership' do
            let(:args) { { membership: :DIRECT, sort: :MOST_ACTIVE_DESC } }

            it 'returns expected runners' do
              request

              expect_graphql_errors_to_be_empty
              expect(graphql_data_at(:group, :runners, :nodes)).to match(
                group_runners.reverse.map { |runner| a_graphql_entity_for(runner) }
              )
            end
          end

          context 'with invalid membership' do
            let(:args) { extra_args.merge(sort: :MOST_ACTIVE_DESC) }

            where(:case_name, :extra_args) do
              'when requesting all available group runners' | { membership: :ALL_AVAILABLE }
              'when requesting group descendant runners' | { membership: :DESCENDANTS }
              'when requesting group runners with unspecified membership' | {}
            end

            with_them do
              it 'returns error' do
                request

                expect_graphql_errors_to_include(
                  'MOST_ACTIVE_DESC sorting is only supported on groups when membership is DIRECT')
              end
            end
          end
        end

        context 'when requesting project runners' do
          let(:args) { { sort: :MOST_ACTIVE_DESC } }
          let(:query) do
            graphql_query_for(:project, { full_path: project.full_path }, query_nodes(:runners, :id, args: args))
          end

          it 'returns error' do
            request

            expect_graphql_errors_to_include(
              'MOST_ACTIVE_DESC sorting is only available for groups or when type is INSTANCE_TYPE')
          end
        end

        context 'with invalid type' do
          let(:args) { extra_args.merge(sort: :MOST_ACTIVE_DESC) }

          where(:case_name, :extra_args) do
            'when requesting GROUP_TYPE runners' | { type: :GROUP_TYPE }
            'when requesting PROJECT_TYPE runners' | { type: :PROJECT_TYPE }
            'when requesting runners without type' | {}
          end

          with_them do
            it 'returns error' do
              request

              expect_graphql_errors_to_include(
                'MOST_ACTIVE_DESC sorting is only available for groups or when type is INSTANCE_TYPE')
            end
          end
        end
      end

      context 'when runner_performance_insights feature is not available' do
        it 'returns error' do
          request

          expect_graphql_errors_to_include(
            'runner_performance_insights feature is required for MOST_ACTIVE_DESC sorting')
        end
      end
    end
  end
end
