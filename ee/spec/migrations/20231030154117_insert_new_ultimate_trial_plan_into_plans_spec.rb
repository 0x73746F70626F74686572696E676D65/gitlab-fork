# frozen_string_literal: true

require 'spec_helper'

require_migration!

RSpec.describe InsertNewUltimateTrialPlanIntoPlans, feature_category: :plan_provisioning do
  describe '#up' do
    it 'adds a new entry to the plans table' do
      expect(new_plan).to be_nil
      expect { migrate! }.to change { Plan.count }.by(1)
      expect(new_plan).to be_present
    end
  end

  describe '#down' do
    before do
      migrate!
    end

    it 'deletes the newly added row' do
      expect(new_plan).to be_present
      expect { schema_migrate_down! }.to change { Plan.count }.by(-1)
      expect(new_plan).to be_nil
    end
  end

  private

  def new_plan
    Plan.find_by(name: 'ultimate_trial_paid_customer')
  end
end
