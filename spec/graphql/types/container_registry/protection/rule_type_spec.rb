# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ContainerRegistryProtectionRule'], feature_category: :container_registry do
  specify { expect(described_class.graphql_name).to eq('ContainerRegistryProtectionRule') }

  specify { expect(described_class.description).to be_present }

  specify { expect(described_class).to require_graphql_authorizations(:admin_container_image) }

  describe 'id' do
    subject { described_class.fields['id'] }

    it { is_expected.to have_non_null_graphql_type(::Types::GlobalIDType[::ContainerRegistry::Protection::Rule]) }
  end

  describe 'repository_path_pattern' do
    subject { described_class.fields['repositoryPathPattern'] }

    it { is_expected.to have_non_null_graphql_type(GraphQL::Types::String) }
  end

  describe 'push_protected_up_to_access_level' do
    subject { described_class.fields['pushProtectedUpToAccessLevel'] }

    it { is_expected.to have_non_null_graphql_type(Types::ContainerRegistry::Protection::RuleAccessLevelEnum) }
  end

  describe 'delete_protected_up_to_access_level' do
    subject { described_class.fields['deleteProtectedUpToAccessLevel'] }

    it { is_expected.to have_non_null_graphql_type(Types::ContainerRegistry::Protection::RuleAccessLevelEnum) }
  end
end
