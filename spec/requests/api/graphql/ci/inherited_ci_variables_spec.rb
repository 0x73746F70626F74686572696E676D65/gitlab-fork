# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).inheritedCiVariables', feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }

  let(:query) do
    %(
      query($limit: Int) {
        project(fullPath: "#{project.full_path}") {
          inheritedCiVariables(first: $limit) {
            pageInfo {
              hasNextPage
              hasPreviousPage
              startCursor
              endCursor
            }
            nodes {
              id
              key
              environmentScope
              groupName
              groupCiCdSettingsPath
              masked
              protected
              raw
              variableType
            }
          }
        }
      }
    )
  end

  def create_variables
    create(:ci_group_variable, group: group)
    create(:ci_group_variable, group: subgroup)
  end

  context 'when user is not a project maintainer' do
    before do
      project.add_developer(user)
    end

    it 'returns nothing' do
      post_graphql(query, current_user: user)

      expect(graphql_data.dig('project', 'inheritedCiVariables')).to be_nil
    end
  end

  context 'when user is a project maintainer' do
    let!(:group_var) do
      create(:ci_group_variable, group: group, key: 'GROUP_VAR_A',
        environment_scope: 'production', masked: false, protected: true, raw: true)
    end

    let!(:subgroup_var) do
      create(:ci_group_variable, group: subgroup, key: 'SUBGROUP_VAR_B',
        masked: true, protected: false, raw: false, variable_type: 'file')
    end

    before do
      project.add_maintainer(user)
    end

    it "returns the project's CI variables inherited from its parent group and ancestors" do
      post_graphql(query, current_user: user)

      expect(graphql_data.dig('project', 'inheritedCiVariables', 'nodes')).to eq([
        {
          'id' => subgroup_var.to_global_id.to_s,
          'key' => 'SUBGROUP_VAR_B',
          'environmentScope' => '*',
          'groupName' => subgroup.name,
          'groupCiCdSettingsPath' => subgroup_var.group_ci_cd_settings_path,
          'masked' => true,
          'protected' => false,
          'raw' => false,
          'variableType' => 'FILE'
        },
        {
          'id' => group_var.to_global_id.to_s,
          'key' => 'GROUP_VAR_A',
          'environmentScope' => 'production',
          'groupName' => group.name,
          'groupCiCdSettingsPath' => group_var.group_ci_cd_settings_path,
          'masked' => false,
          'protected' => true,
          'raw' => true,
          'variableType' => 'ENV_VAR'
        }
      ])
    end

    context 'when limiting the number of results' do
      it 'returns pagination information' do
        post_graphql(query, current_user: user, variables: { limit: 1 })

        expect(has_next_page).to be_truthy
        expect(has_prev_page).to be_falsey

        expect(graphql_data.dig('project', 'inheritedCiVariables', 'nodes')).to eq([
          {
            'id' => subgroup_var.to_global_id.to_s,
            'key' => 'SUBGROUP_VAR_B',
            'environmentScope' => '*',
            'groupName' => subgroup.name,
            'groupCiCdSettingsPath' => subgroup_var.group_ci_cd_settings_path,
            'masked' => true,
            'protected' => false,
            'raw' => false,
            'variableType' => 'FILE'
          }
        ])
      end
    end

    it 'avoids N+1 database queries' do
      create_variables

      baseline = ActiveRecord::QueryRecorder.new do
        run_with_clean_state(query, context: { current_user: user })
      end

      create_variables

      multi = ActiveRecord::QueryRecorder.new do
        run_with_clean_state(query, context: { current_user: user })
      end

      expect(multi).not_to exceed_query_limit(baseline)
    end
  end

  def pagination_info
    graphql_data_at('project', 'inheritedCiVariables', 'pageInfo')
  end

  def has_next_page
    pagination_info['hasNextPage']
  end

  def has_prev_page
    pagination_info['hasPreviousPage']
  end
end
