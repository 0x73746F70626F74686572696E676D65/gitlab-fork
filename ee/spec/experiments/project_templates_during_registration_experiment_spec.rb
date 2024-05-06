# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectTemplatesDuringRegistrationExperiment, :experiment, feature_category: :activation do
  let(:user) { build_stubbed(:user) }

  context 'with control experience' do
    before do
      stub_experiments(project_templates_during_registration: :control)
    end

    it 'registers control behavior' do
      expect(experiment(:project_templates_during_registration, user: user))
        .to register_behavior(:control)
        .with(nil)

      expect { experiment(:project_templates_during_registration, user: user).run }
        .not_to raise_error
    end
  end

  context 'with candidate experience' do
    before do
      stub_experiments(project_templates_during_registration: :candidate)
    end

    it 'registers candidate behavior' do
      expect(experiment(:project_templates_during_registration, user: user))
        .to register_behavior(:candidate)
        .with(nil)

      expect { experiment(:project_templates_during_registration, user: user).run }
        .not_to raise_error
    end
  end
end
