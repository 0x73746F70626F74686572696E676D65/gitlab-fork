# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::CountryAccessLog, :saas, feature_category: :instance_resiliency do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:country_access_log) }

    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:country_code) }
    it { is_expected.to define_enum_for(:country_code).with_values(**described_class::COUNTRY_CODES) }
    it { is_expected.to validate_presence_of(:access_count) }
    it { is_expected.to validate_numericality_of(:access_count).is_greater_than_or_equal_to(0) }

    context 'when access count > 0' do
      subject { build(:country_access_log, access_count: 1) }

      it { is_expected.to validate_presence_of(:first_access_at) }
      it { is_expected.to validate_presence_of(:last_access_at) }
    end
  end

  context 'with loose foreign key on country_access_logs.user_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:user) }
      let_it_be(:model) { create(:country_access_log, user: parent) }
    end
  end
end
