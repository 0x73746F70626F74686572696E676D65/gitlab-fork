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
  end

  describe 'Custom Roles' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user, reload: true) { create(:user) }
    let_it_be(:group, reload: true) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:group_runner) { create(:ci_runner, :group, groups: [group]) }
    let_it_be(:project_runner) { create(:ci_runner, :project, projects: [project]) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    where(:custom_permission, :feature_flag, :abilities) do
      :admin_runners | true | [:assign_runner, :read_runner, :update_runner, :delete_runner]
      :read_runners | false | [:read_runner]
    end

    with_them do
      [:group_runner, :project_runner].each do |runner_type|
        context "with a #{runner_type}" do
          subject(:policy) { described_class.new(user, public_send(runner_type)) }

          it { expect_disallowed(*abilities) }

          context "when the user has the `#{params[:custom_permission]}` permission" do
            let!(:role) { create(:member_role, :guest, custom_permission, namespace: group) }
            let!(:membership) { create(:group_member, :guest, member_role: role, user: user, source: group) }

            it { expect_allowed(*abilities) }

            context "with the feature flag disabled" do
              before do
                stub_feature_flags("custom_ability_#{custom_permission}": false)
              end

              it do
                skip "feature flag 'custom_ability_#{custom_permission}' does not exist" unless feature_flag
                expect_disallowed(*abilities)
              end
            end

            context "with the custom roles feature disabled" do
              before do
                stub_licensed_features(custom_roles: false)
              end

              it { expect_disallowed(*abilities) }
            end
          end
        end
      end
    end
  end
end
