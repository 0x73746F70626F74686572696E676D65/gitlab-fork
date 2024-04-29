# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ApprovalPolicy'], feature_category: :security_policy_management do
  let(:fields) do
    %i[name description edit_path enabled policy_scope updated_at yaml source
      user_approvers all_group_approvers role_approvers deprecatedProperties]
  end

  it { expect(described_class).to have_graphql_fields(fields) }
end
