# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting list of branch rules for a project' do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository, :public) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:branch_name_a) { 'branch_name_a' }
  let_it_be(:branch_name_b) { 'wildcard-*' }
  let_it_be(:branch_rules) { [branch_rule_a, branch_rule_b] }

  let_it_be(:branch_rule_a) do
    create(:protected_branch, project: project, name: branch_name_a)
  end

  let_it_be(:branch_rule_b) do
    create(:protected_branch, project: project, name: branch_name_b)
  end

  let(:branch_rules_data) { graphql_data_at('project', 'branchRules', 'edges') }
  let(:variables) { { path: project.full_path } }
  # fields must use let as the all_graphql_fields_for also configures some spies
  let(:fields) { all_graphql_fields_for('BranchRule') }
  let(:query) do
    <<~GQL
    query($path: ID!, $n: Int, $cursor: String) {
      project(fullPath: $path) {
        branchRules(first: $n, after: $cursor) {
          pageInfo {
            hasNextPage
            hasPreviousPage
          }
          edges {
            cursor
            node {
              #{fields}
            }
          }
        }
      }
    }
    GQL
  end

  context 'when the user does not have read_protected_branch abilities' do
    before do
      project.add_guest(current_user)
      post_graphql(query, current_user: current_user, variables: variables)
    end

    it_behaves_like 'a working graphql query'

    it 'hides branch rules data' do
      expect(branch_rules_data).to be_empty
    end
  end

  context 'when the user does have read_protected_branch abilities' do
    before do
      project.add_maintainer(current_user)
      post_graphql(query, current_user: current_user, variables: variables)
    end

    it_behaves_like 'a working graphql query'

    it 'returns branch rules data' do
      expect(branch_rules_data.dig(0, 'node', 'name')).to be_present
      expect(branch_rules_data.dig(0, 'node', 'isDefault')).to be(true).or be(false)
      expect(branch_rules_data.dig(0, 'node', 'branchProtection')).to be_present
      expect(branch_rules_data.dig(0, 'node', 'createdAt')).to be_present
      expect(branch_rules_data.dig(0, 'node', 'updatedAt')).to be_present

      expect(branch_rules_data.dig(1, 'node', 'name')).to be_present
      expect(branch_rules_data.dig(1, 'node', 'isDefault')).to be(true).or be(false)
      expect(branch_rules_data.dig(1, 'node', 'branchProtection')).to be_present
      expect(branch_rules_data.dig(1, 'node', 'createdAt')).to be_present
      expect(branch_rules_data.dig(1, 'node', 'updatedAt')).to be_present
    end

    context 'when limiting the number of results' do
      let(:branch_rule_limit) { 1 }
      let(:variables) { { path: project.full_path, n: branch_rule_limit } }
      let(:next_variables) do
        { path: project.full_path, n: branch_rule_limit, cursor: last_cursor }
      end

      it_behaves_like 'a working graphql query'

      it 'returns pagination information' do
        expect(branch_rules_data.size).to eq(branch_rule_limit)
        expect(has_next_page).to be_truthy
        expect(has_prev_page).to be_falsey
        post_graphql(query, current_user: current_user, variables: next_variables)
        expect(branch_rules_data.size).to eq(branch_rule_limit)
        expect(has_next_page).to be_falsey
        expect(has_prev_page).to be_truthy
      end

      context 'when no limit is provided' do
        let(:branch_rule_limit) { nil }

        it 'returns all branch_rules' do
          expect(branch_rules_data.size).to eq(branch_rules.size)
        end
      end
    end
  end

  def pagination_info
    graphql_data_at('project', 'branchRules', 'pageInfo')
  end

  def has_next_page
    pagination_info['hasNextPage']
  end

  def has_prev_page
    pagination_info['hasPreviousPage']
  end

  def last_cursor
    branch_rules_data.last['cursor']
  end
end
