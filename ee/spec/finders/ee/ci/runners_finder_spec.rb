# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::RunnersFinder, '#execute', feature_category: :fleet_visibility do
  subject(:execute) do
    described_class.new(current_user: user, params: params).execute
  end

  context 'when sorting' do
    let(:params) { { sort: sort_key } }

    context 'with sort param equal to most_active_desc' do
      let_it_be(:admin) { create(:user, :admin) }
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:instance_runners) { create_list(:ci_runner, 3) }
      let_it_be(:group_runners) { create_list(:ci_runner, 3, :group, groups: [group]) }

      let(:sort_key) { 'most_active_desc' }

      before_all do
        instance_runners.map.with_index do |runner, number_of_builds|
          create_list(:ci_build, number_of_builds, :picked, runner: runner, project: project)
        end

        group_runners.map.with_index do |runner, number_of_builds|
          create_list(:ci_build, 3 + number_of_builds, :picked, runner: runner, project: project)
        end
      end

      context 'when requesting all runners' do
        let(:params) do
          { sort: sort_key }
        end

        context 'when admin', :enable_admin_mode do
          let(:user) { admin }

          it 'raises an error' do
            expect { execute }.to raise_error(
              ArgumentError, 'most_active_desc can only be used on instance and group runners'
            )
          end
        end
      end

      context 'when requesting instance runners' do
        let(:params) do
          { type_type: :instance_type, sort: sort_key }
        end

        context 'when admin', :enable_admin_mode do
          let(:user) { admin }

          it 'returns runners with the most running builds' do
            is_expected.to eq(instance_runners[1..5].reverse)
          end
        end
      end

      context 'when requesting group runners' do
        let(:base_params) do
          { group: group, sort: sort_key }
        end

        let(:params) do
          base_params.merge(extra_params)
        end

        context 'with user as group owner' do
          let_it_be(:user) { create(:user).tap { |user| group.add_owner(user) } }

          context 'with direct membership' do
            let(:extra_params) { { membership: :direct } }

            it 'returns group runners with the most running builds' do
              is_expected.to eq(group_runners.reverse)
            end
          end

          context 'with invalid membership' do
            using RSpec::Parameterized::TableSyntax

            where(:case_name, :extra_params) do
              'when requesting all available group runners' | { membership: :all_available }
              'when requesting group descendant runners' | { membership: :descendants }
              'when requesting group runners with unspecified membership' | {}
            end

            with_them do
              it 'raises an error' do
                expect { execute }.to raise_error(
                  ArgumentError, 'most_active_desc is only supported on groups when membership is direct'
                )
              end
            end
          end
        end
      end

      context 'when requesting project runners' do
        let(:params) do
          { project: project, sort: sort_key }
        end

        context 'with user as project owner' do
          let_it_be(:user) { create(:user).tap { |user| project.add_owner(user) } }

          it 'raises an error' do
            expect { execute }.to raise_error(
              ArgumentError, 'most_active_desc can only be used on instance and group runners'
            )
          end
        end
      end
    end
  end
end
