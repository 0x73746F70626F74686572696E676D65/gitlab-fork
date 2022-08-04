# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::UnassignRunnerService, '#execute' do
  subject(:execute) { described_class.new(runner_project, user).execute }

  let_it_be(:runner) { create(:ci_runner, :project, projects: [project]) }
  let_it_be(:project) { create(:project) }

  let(:runner_project) { runner.runner_projects.last }

  context 'without user' do
    let(:user) { nil }

    it 'does not destroy runner_project', :aggregate_failures do
      expect(runner_project).not_to receive(:destroy)
      expect { execute }.not_to change { runner.runner_projects.count }.from(1)

      is_expected.to be_error
    end
  end

  context 'with unauthorized user' do
    let(:user) { build(:user) }

    it 'does not call destroy on runner_project' do
      expect(runner).not_to receive(:destroy)

      is_expected.to be_error
    end
  end

  context 'with admin user', :enable_admin_mode do
    let(:user) { create_default(:user, :admin) }

    context 'with destroy returning false' do
      it 'returns error response' do
        expect(runner_project).to receive(:destroy).once.and_return(false)

        is_expected.to be_error
      end
    end

    context 'with destroy returning true' do
      before do
        # The factory bot doesn't save the project association by default, so let's make sure that's done
        runner_project.update!(project: project)
      end

      it 'returns success response' do
        expect(runner_project).to receive(:destroy).once.and_return(true)

        is_expected.to be_success
      end
    end
  end
end
