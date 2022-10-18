# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['BranchRule'] do
  include GraphqlHelpers

  subject { described_class }

  let(:fields) do
    %i[
      name
      isDefault
      branch_protection
      created_at
      updated_at
    ]
  end

  specify { is_expected.to require_graphql_authorizations(:read_protected_branch) }

  specify { is_expected.to have_graphql_fields(fields).at_least }
end
