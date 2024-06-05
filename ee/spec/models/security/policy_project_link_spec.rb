# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicyProjectLink, feature_category: :security_policy_management do
  subject { create(:security_policy_project_link) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:security_policy) }

    it { is_expected.to validate_uniqueness_of(:security_policy).scoped_to(:project_id) }
  end
end
