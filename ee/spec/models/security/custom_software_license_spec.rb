# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::CustomSoftwareLicense, feature_category: :security_policy_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    subject(:custom_software_license) { build(:custom_software_license) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to(validate_uniqueness_of(:name).scoped_to(%i[project_id])) }
  end
end
