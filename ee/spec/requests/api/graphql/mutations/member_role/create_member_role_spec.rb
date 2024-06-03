# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'creating member role', feature_category: :permissions do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:current_user) { create(:user) }

  let(:name) { 'member role name' }
  let(:group_path) { group.path }
  let(:permissions) { MemberRole.all_customizable_permissions.keys.map(&:to_s).map(&:upcase) }
  let(:input) do
    {
      group_path: group_path,
      base_access_level: 'GUEST',
      permissions: permissions
    }
  end

  let(:fields) do
    <<~FIELDS
      errors
      memberRole {
        id
        name
        description
        enabledPermissions {
          nodes {
            value
          }
        }
      }
    FIELDS
  end

  let(:mutation) { graphql_mutation(:member_role_create, input, fields) }

  subject(:create_member_role) { graphql_mutation_response(:member_role_create) }

  before_all do
    group.add_owner(current_user)
  end

  shared_examples 'a mutation that creates a member role' do
    it 'returns success', :aggregate_failures do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to be_nil

      expect(create_member_role['memberRole']['enabledPermissions']['nodes'].flat_map(&:values))
        .to match_array(permissions)
    end

    it 'creates the member role', :aggregate_failures do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { MemberRole.count }.by(1)

      member_role = MemberRole.last

      expect(member_role.read_vulnerability).to eq(true)
    end
  end

  context 'without the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: false)
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  # to make this spec passing add a new argument to the mutation
  # when implementing a new custom role permission
  context 'with the custom roles feature' do
    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when on SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when creating a group level member role' do
        context 'when the current user is a maintainer' do
          before_all do
            group.add_maintainer(current_user)
          end

          it_behaves_like 'a mutation that returns a top-level access error'
        end

        context 'when the current user is an owner' do
          it_behaves_like 'a mutation that creates a member role'

          context 'with unknown permissions' do
            let(:permissions) { ['read_unknown'] }

            it 'returns an error' do
              post_graphql_mutation(mutation, current_user: current_user)

              expect(graphql_errors).to be_present
            end
          end

          context 'with missing group_path' do
            let(:group_path) { nil }

            it_behaves_like 'a mutation that returns top-level errors',
              errors: ['group_path argument is required.']
          end

          context 'with an invalid group_path' do
            let(:group_path) { 'invalid_path' }

            it_behaves_like 'a mutation that returns top-level errors',
              errors: ["The resource that you are attempting to access does not exist or " \
                       "you don't have permission to perform this action"]
          end

          context 'with missing arguments' do
            before do
              input.delete(:base_access_level)
            end

            it_behaves_like 'an invalid argument to the mutation', argument_name: 'baseAccessLevel'
          end
        end
      end
    end

    context 'when on self-managed', :enable_admin_mode do
      let(:group_path) { nil }

      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'when the current user is not an instance admin' do
        it_behaves_like 'a mutation that returns a top-level access error',
          errors: ["The resource that you are attempting to access does not exist or " \
                   "you don't have permission to perform this action"]
      end

      context 'when the current user is an instance admin' do
        before do
          current_user.update!(admin: true)
        end

        context 'when creating a group level member role' do
          let(:group_path) { group.path }

          it_behaves_like 'a mutation that returns top-level errors',
            errors: ["group_path argument is not allowed on self-managed instances."]
        end

        context 'when creating a instance level member role' do
          it_behaves_like 'a mutation that creates a member role'
        end
      end
    end
  end
end
