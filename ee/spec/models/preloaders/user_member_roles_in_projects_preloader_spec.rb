# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Preloaders::UserMemberRolesInProjectsPreloader, feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, :private, group: subgroup) }
  let_it_be(:project_member) { create(:project_member, :guest, user: user, source: project) }

  let(:project_list) { [project] }

  subject(:result) { described_class.new(projects: project_list, user: user).execute }

  def ability_requirements(ability)
    ability_definition = MemberRole.all_customizable_permissions[ability]
    requirements = ability_definition[:requirements]&.map(&:to_sym) || []
    requirements & MemberRole.all_customizable_project_permissions
  end

  def create_member_role(ability, member)
    build(:member_role, :guest, namespace: group, read_code: false).tap do |record|
      record.assign_attributes(ability => true)
      ability_requirements(ability).each do |requirement|
        record.assign_attributes(requirement => true)
      end
      record.save!
      record.members << member
    end
  end

  shared_examples 'custom roles' do |ability|
    let(:expected_abilities) { [ability, *ability_requirements(ability)].compact }

    context 'when custom_roles license is not enabled on project root ancestor' do
      it 'returns project id with nil ability value' do
        stub_licensed_features(custom_roles: false)
        create_member_role(ability, project_member)

        expect(result).to eq(project.id => nil)
      end
    end

    context 'when custom_roles license is enabled on project root ancestor' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'when project has custom role' do
        let_it_be(:member_role) do
          create_member_role(ability, project_member)
        end

        context "when custom role has #{ability}: true" do
          context 'when Array of project passed' do
            it 'returns the project_id with a value array that includes the ability' do
              expect(result[project.id]).to match_array(expected_abilities)
            end

            context 'when saas', :saas do
              let_it_be(:subscription) do
                create(:gitlab_subscription, namespace: group, hosted_plan: create(:ultimate_plan))
              end

              before do
                stub_ee_application_setting(should_check_namespace_plan: true)
              end

              it 'avoids N+1 queries' do
                projects = [project]
                control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
                  described_class.new(projects: projects, user: user).execute
                end

                projects << create(:project, :private, group: create(:group, parent: group))

                expect do
                  described_class.new(projects: projects, user: user).execute
                end.to issue_same_number_of_queries_as(control).or_fewer
              end
            end
          end

          context 'when ActiveRecord::Relation of projects passed' do
            let(:project_list) { Project.where(id: project.id) }

            it 'returns the project_id with a value array that includes the ability' do
              expect(result[project.id]).to match_array(expected_abilities)
            end
          end
        end
      end

      context 'when project namespace has a custom role with ability: true' do
        let_it_be(:group_member) { create(:group_member, :guest, user: user, source: project.namespace) }
        let_it_be(:member_role) do
          create_member_role(ability, group_member)
        end

        it 'returns the project_id with a value array that includes the ability' do
          expect(result[project.id]).to match_array(expected_abilities)
        end
      end

      context 'when a user is assigned to custom roles in both group and project' do
        let_it_be(:group_member) { create(:group_member, :guest, user: user, source: group) }

        it 'returns abilities assigned to the custom role inside both project and group' do
          create_member_role(ability, group_member)
          create_member_role(:read_code, project_member)

          expect(result[project.id]).to match_array(expected_abilities.push(:read_code).uniq)
        end
      end

      context 'when a user is assigned to custom roles in group, subgroup and project' do
        let_it_be(:group_member) { create(:group_member, :guest, user: user, source: group) }
        let_it_be(:sub_group_member) { create(:group_member, :guest, user: user, source: subgroup) }

        it 'returns abilities assigned to the custom role inside both project and group' do
          create_member_role(ability, group_member)
          create_member_role(:read_code, project_member)
          create_member_role(:read_vulnerability, sub_group_member)

          expect(result[project.id]).to match_array(expected_abilities.concat([:read_code, :read_vulnerability]).uniq)
        end
      end

      context 'when project membership has no custom role' do
        let_it_be(:project) { create(:project, :private, :in_group) }

        it 'returns project id with empty value array' do
          expect(result).to eq(project.id => [])
        end
      end

      context 'when user has custom role that enables custom permission outside of project hierarchy' do
        it 'ignores custom role outside of project hierarchy' do
          # subgroup is within parent group of project but not above project
          subgroup = create(:group, parent: group)
          subgroup_member = create(:group_member, :guest, user: user, source: subgroup)
          create_member_role(ability, subgroup_member)

          expect(result).to eq({ project.id => [] })
        end
      end
    end

    it 'avoids N+1 queries' do
      projects = [project]
      described_class.new(projects: projects, user: user).execute

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        described_class.new(projects: projects, user: user).execute
      end

      projects = [project, create(:project, :private, :in_group)]

      expect { described_class.new(projects: projects, user: user).execute }.to issue_same_number_of_queries_as(control)
    end
  end

  MemberRole.all_customizable_project_permissions.each do |ability|
    it_behaves_like 'custom roles', ability
  end
end
