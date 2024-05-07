# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Runner, feature_category: :hosted_runners do
  let(:shared_runners_minutes) { 400 }

  before do
    allow(::Gitlab::CurrentSettings).to receive(:shared_runners_minutes) { shared_runners_minutes }
  end

  describe 'ci associations' do
    it 'has one cost setting' do
      is_expected.to have_one(:cost_settings)
      .inverse_of(:runner)
      .class_name('Ci::Minutes::CostSetting')
      .with_foreign_key(:runner_id)
    end
  end

  describe '#cost_factor_for_project' do
    subject { runner.cost_factor_for_project(project) }

    context 'with group type runner' do
      let(:runner) { create(:ci_runner, :group) }

      ::Gitlab::VisibilityLevel.options.each do |level_name, level_value|
        context "with #{level_name}" do
          let(:project) { create(:project, visibility_level: level_value) }

          it { is_expected.to eq(0.0) }
        end
      end
    end

    context 'with project type runner' do
      let(:runner) { create(:ci_runner, :project) }

      ::Gitlab::VisibilityLevel.options.each do |level_name, level_value|
        context "with #{level_name}" do
          let(:project) { create(:project, visibility_level: level_value) }

          it { is_expected.to eq(0.0) }
        end
      end
    end

    context 'with instance type runner' do
      let(:runner) do
        create(
          :ci_runner,
          :instance,
          private_projects_minutes_cost_factor: 1.1,
          public_projects_minutes_cost_factor: 0.008
        )
      end

      context 'with private visibility level' do
        let(:project) { create(:project, :private) }

        it { is_expected.to eq(1.1) }

        context 'with unlimited minutes' do
          let(:shared_runners_minutes) { 0 }

          it { is_expected.to eq(0) }
        end
      end

      context 'with public visibility level' do
        let(:project) { create(:project, :public) }

        it { is_expected.to eq(0.008) }
      end

      context 'with internal visibility level' do
        let(:project) { create(:project, :internal) }

        it { is_expected.to eq(1.1) }
      end
    end
  end

  describe '#cost_factor_enabled?' do
    let_it_be_with_reload(:project) do
      namespace = create(:group, created_at: Date.new(2021, 7, 16))
      create(:project, namespace: namespace)
    end

    context 'when the project has any cost factor' do
      let(:runner) do
        create(:ci_runner, :instance,
          private_projects_minutes_cost_factor: 1,
          public_projects_minutes_cost_factor: 0)
      end

      subject { runner.cost_factor_enabled?(project) }

      it { is_expected.to be_truthy }

      context 'with unlimited minutes' do
        let(:shared_runners_minutes) { 0 }

        it { is_expected.to be_falsy }
      end
    end

    context 'when the project has no cost factor' do
      it 'returns false' do
        runner = create(
          :ci_runner, :instance,
          private_projects_minutes_cost_factor: 0,
          public_projects_minutes_cost_factor: 0
        )

        expect(runner.cost_factor_enabled?(project)).to be_falsy
      end
    end
  end

  describe '.any_shared_runners_with_enabled_cost_factor' do
    subject(:runners) { described_class.any_shared_runners_with_enabled_cost_factor?(project) }

    let_it_be(:namespace) { create(:group) }

    context 'when project is public' do
      let_it_be(:project) { create(:project, :public, namespace: namespace) }
      let_it_be(:runner) { create(:ci_runner, :instance, public_projects_minutes_cost_factor: 0.0) }

      context 'when public cost factor is greater than zero' do
        before do
          runner.update!(public_projects_minutes_cost_factor: 0.008)
        end

        it 'returns true' do
          expect(runners).to be_truthy
        end
      end

      context 'when public cost factor is zero' do
        it 'returns false' do
          expect(runners).to be_falsey
        end
      end
    end

    context 'when project is private' do
      let_it_be(:project) { create(:project, :private, namespace: namespace) }
      let_it_be(:runner) { create(:ci_runner, :instance, private_projects_minutes_cost_factor: 1.0) }

      context 'when private cost factor is greater than zero' do
        it 'returns true' do
          expect(runners).to be_truthy
        end
      end

      context 'when private cost factor is zero' do
        before do
          runner.update!(private_projects_minutes_cost_factor: 0.0)
        end

        it 'returns false' do
          expect(runners).to be_falsey
        end
      end
    end
  end

  describe '#allowed_for_plans?', :saas do
    let(:namespace) { create(:namespace_with_plan, plan: plan) }
    let(:project) { create(:project, namespace: namespace) }
    let(:pipeline) { create(:ci_pipeline, project: project) }
    let(:build) { create(:ci_build, pipeline: pipeline) }

    subject { create(:ci_runner, :instance, allowed_plans: allowed_plans).allowed_for_plans?(build) }

    context 'when allowed plans are not defined' do
      let(:allowed_plans) { [] }
      let(:plan) { :premium_plan }

      it { is_expected.to be_truthy }
    end

    context 'when allowed_plans are defined' do
      let(:allowed_plans) { %w[silver premium] }

      context 'when plans match allowed plans' do
        let(:plan) { :premium_plan }

        it { is_expected.to be_truthy }
      end

      context 'when plans do not match allowed plans' do
        let(:plan) { :ultimate_plan }

        it { is_expected.to be_falsey }
      end
    end

    context 'when ci_runner_separation_by_plan feature flag is disabled' do
      let(:allowed_plans) { %w[silver premium] }
      let(:plan) { :ultimate_plan }

      before do
        stub_feature_flags(ci_runner_separation_by_plan: false)
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '.order_most_active_desc' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:instance_runners) { create_list(:ci_runner, 2) }
    let_it_be(:group_runners) { create_list(:ci_runner, 3, :group, groups: [group]) }

    let(:child_scope) { described_class.all }

    subject(:scope) { child_scope.order_most_active_desc.pluck(:id) }

    describe '.with_top_running_builds_of_runner_type' do
      let(:child_scope) { described_class.with_top_running_builds_of_runner_type(runner_type) }

      context 'with no running builds' do
        context 'when runner_type is instance_type' do
          let(:runner_type) { :instance_type }

          it { is_expected.to be_empty }
        end

        context 'when runner_type is group_type' do
          let(:runner_type) { :group_type }

          it { is_expected.to be_empty }
        end
      end

      context 'with running builds' do
        before_all do
          # Create builds for each runner
          instance_runners.map.with_index do |runner, idx|
            create_list(:ci_build, 3 - idx, :picked, runner: runner, project: project)
          end

          group_runners.map.with_index do |runner, idx|
            create_list(:ci_build, 2 - idx, :picked, runner: runner, project: project)
          end
        end

        context 'when runner_type is instance_type' do
          let(:runner_type) { :instance_type }

          it 'returns instance runners sorted by running builds' do
            is_expected.to eq(instance_runners.pluck(:id))
          end

          it 'limits the number of running builds counted and sorts by id desc' do
            stub_const("EE::Ci::Runner::MOST_ACTIVE_RUNNERS_BUILDS_LIMIT", 2)

            # The first 2 instance runners with most builds have 2 or more builds, but we're capping at 2 builds,
            # so they are all tied for 1st place, and therefore sorted by id desc
            runner_ids = instance_runners.pluck(:id)
            expected_runner_ids = runner_ids[0..1].sort.reverse + runner_ids[2..]

            is_expected.to eq(expected_runner_ids)
          end
        end

        context 'when runner_type is group_type' do
          let(:runner_type) { :group_type }

          it 'returns group runners sorted by running builds' do
            is_expected.to eq(group_runners.pluck(:id).take(2)) # Only returns runners that have builds
          end
        end
      end
    end

    describe '.with_top_running_builds_by_namespace_id' do
      let(:child_scope) { described_class.with_top_running_builds_by_namespace_id(group.id) }

      context 'with no running builds' do
        it { is_expected.to be_empty }
      end

      context 'with running builds' do
        before_all do
          group_runners.map.with_index do |runner, idx|
            create_list(:ci_build, 3 - idx, :picked, runner: runner, project: project)
          end
        end

        it 'returns group runners sorted by running builds' do
          is_expected.to eq(group_runners.pluck(:id))
        end

        it 'limits the number of running builds counted and sorts by id desc' do
          stub_const("EE::Ci::Runner::MOST_ACTIVE_RUNNERS_BUILDS_LIMIT", 2)

          runner_ids = group_runners.pluck(:id)

          # The first 2 group runners with most builds have 2 or more builds, but we're capping at 2 builds,
          # so they are all tied for 1st place, and therefore sorted by id desc
          expected_runner_ids = runner_ids[0..1].reverse + runner_ids[2..]

          is_expected.to eq(expected_runner_ids)
        end
      end
    end
  end
end
