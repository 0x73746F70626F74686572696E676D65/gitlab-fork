# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.member_role_permissions', feature_category: :permissions do
  include GraphqlHelpers

  let(:fields) do
    <<~QUERY
      nodes {
        availableFor
        description
        name
        requirements
        value
      }
    QUERY
  end

  let(:query) do
    graphql_query_for('memberRolePermissions', fields)
  end

  def redefine_enum!
    # We need to override the enum values, because they are defined at boot time
    # and stubbing the permissions won't have an effect.
    Types::MemberRoles::PermissionsEnum.class_eval do
      def self.enum_values(_)
        MemberRole.all_customizable_permissions.map do |key, _|
          enum_value_class.new(key.upcase, value: key, owner: self)
        end
      end
    end
  end

  def reset_enum!
    # Remove the override
    Types::MemberRoles::PermissionsEnum.singleton_class.remove_method(:enum_values)
  end

  before do
    allow(MemberRole).to receive(:all_customizable_permissions).and_return(
      {
        admin_ability_one: {
          description: 'Allows admin access to do something.',
          project_ability: true
        },
        admin_ability_two: {
          description: 'Allows admin access to do something else.',
          requirements: [:read_ability_two],
          group_ability: true
        },
        read_ability_two: {
          description: 'Allows read access to do something else.',
          group_ability: true,
          project_ability: true
        }
      }
    )

    redefine_enum!

    post_graphql(query)
  end

  after do
    reset_enum!
  end

  subject { graphql_data.dig('memberRolePermissions', 'nodes') }

  it_behaves_like 'a working graphql query'

  it 'returns all customizable ablities' do
    expected_result = [
      { 'availableFor' => ['project'], 'description' => 'Allows admin access to do something.',
        'name' => 'Admin ability one', 'requirements' => nil, 'value' => 'ADMIN_ABILITY_ONE' },
      { 'availableFor' => %w[project group], 'description' => 'Allows read access to do something else.',
        'name' => 'Read ability two', 'requirements' => nil, 'value' => 'READ_ABILITY_TWO' },
      { 'availableFor' => ['group'], 'description' => "Allows admin access to do something else.",
        'requirements' => ['READ_ABILITY_TWO'], 'name' => 'Admin ability two', 'value' => 'ADMIN_ABILITY_TWO' }
    ]

    expect(subject).to match_array(expected_result)
  end
end
