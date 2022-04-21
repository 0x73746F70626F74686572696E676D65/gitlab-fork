# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Status::Build::Manual do
  let_it_be(:user) { create(:user) }
  let_it_be_with_refind(:job) { create(:ci_build, :manual, :deploy_to_production, :with_deployment) }

  describe '#illustration' do
    subject(:illustration) do
      described_class
        .new(Gitlab::Ci::Status::Core.new(job, user))
        .illustration
    end

    it { is_expected.to include(:image, :size, :title, :content) }

    context 'with protected environments' do
      let_it_be(:protected_environment) do
        create(:protected_environment, name: job.environment, project: job.project)
      end

      let_it_be(:protected_environment_deploy_access_level) do
        create(:protected_environment_deploy_access_level, :maintainer_access,
          protected_environment: protected_environment)
      end

      before do
        stub_licensed_features(protected_environments: true)
      end

      context 'when user does not have access' do
        before do
          job.project.add_developer(user)
        end

        it { expect(illustration[:content]).to match /This deployment job does not run automatically and must be started manually, but you do not have access to this job's protected environment/ }
      end

      context 'when user has access' do
        before do
          job.project.add_maintainer(user)
        end

        it { expect(illustration[:content]).to match /This job requires manual intervention to start/ }
      end
    end
  end
end
