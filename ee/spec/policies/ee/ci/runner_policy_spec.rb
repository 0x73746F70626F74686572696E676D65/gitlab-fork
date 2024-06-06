# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnerPolicy, feature_category: :runner do
  describe 'cicd runners' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    subject(:policy) { described_class.new(user, runner) }

    context 'with auditor access' do
      let_it_be(:user) { create(:auditor) }
      let_it_be(:instance_runner) { create(:ci_runner, :instance) }
      let_it_be(:group_runner) { create(:ci_runner, :group, groups: [group]) }
      let_it_be(:project_runner) { create(:ci_runner, :project, projects: [project]) }

      context 'with instance runner' do
        let(:runner) { instance_runner }

        it 'allows only read permissions' do
          expect_allowed :read_runner
          expect_allowed :read_builds
          expect_disallowed :assign_runner, :update_runner, :delete_runner
        end
      end

      context 'with group runner' do
        let(:runner) { group_runner }

        it 'allows only read permissions' do
          expect_allowed :read_runner
          expect_allowed :read_builds
          expect_disallowed :assign_runner, :update_runner, :delete_runner
        end
      end

      context 'with project runner' do
        let(:runner) { project_runner }

        it 'allows only read permissions' do
          expect_allowed :read_runner
          expect_allowed :read_builds
          expect_disallowed :assign_runner, :update_runner, :delete_runner
        end
      end
    end

    context 'with `admin_runner` access via a custom role' do
      let_it_be_with_reload(:user) { create(:user) }
      let_it_be(:role) { create(:member_role, :guest, :admin_runners, namespace: project.group) }

      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'with project runner' do
        let_it_be(:membership) { create(:project_member, :guest, member_role: role, user: user, project: project) }
        let_it_be_with_reload(:runner) { create(:ci_runner, :project, projects: [project]) }

        it { expect_allowed :read_runner }

        it 'avoids N+1 queries' do
          control = ActiveRecord::QueryRecorder.new do
            described_class.new(user, runner).allowed?(:read_runner)
          end

          create_list(:project, 3).each do |project|
            project.add_member(user, :guest)
            runner.runner_projects.create!(project: project)
          end

          expect do
            described_class.new(user, runner).allowed?(:read_runner)
          end.not_to exceed_query_limit(control)
        end

        context 'with `custom_ability_admin_runners` disabled' do
          before do
            stub_feature_flags(custom_ability_admin_runners: false)
          end

          it { expect_disallowed :read_runner }
        end
      end
    end
  end
end
