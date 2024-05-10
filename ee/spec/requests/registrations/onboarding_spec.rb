# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Registration Onboarding', type: :request, feature_category: :onboarding do
  describe '#onboarding' do
    let_it_be(:project) { create(:project) }

    it 'redirects to learn gitlab show' do
      expect(get(onboarding_project_learn_gitlab_path(project))).to redirect_to(project_learn_gitlab_path(project))
    end
  end
end
