# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppSec::ContainerScanning::ScanImageService, feature_category: :software_composition_analysis do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, developers: user) }

  let(:user_id) { user.id }
  let(:project_id) { project.id }
  let(:image) { "registry.gitlab.com/gitlab-org/security-products/dast/webgoat-8.0@test:latest" }

  before do
    allow(Gitlab::ApplicationRateLimiter).to receive(:throttled_request?).and_return(false)
  end

  describe '#pipeline_config' do
    subject(:pipeline_config) do
      described_class.new(
        image: image,
        project_id: project_id,
        user_id: user_id
      ).pipeline_config
    end

    it 'generates a valid yaml ci config' do
      lint = Gitlab::Ci::Lint.new(project: project, current_user: user)
      result = lint.validate(pipeline_config)

      expect(result).to be_valid
    end
  end

  describe '#execute' do
    subject(:execute) do
      described_class.new(
        image: image,
        project_id: project_id,
        user_id: user_id
      ).execute
    end

    context 'when a project is not present' do
      let(:project_id) { nil }

      it { is_expected.to be_nil }
    end

    context 'when a user is not present' do
      let(:user_id) { nil }

      it { is_expected.to be_nil }
    end

    context 'when a valid project and user is present' do
      it 'creates a pipeline' do
        expect { execute }.to change { Ci::Pipeline.count }.by(1)
      end
    end

    context 'when the project has exceeded the daily scan limit' do
      before do
        allow(Gitlab::ApplicationRateLimiter).to receive(:throttled?).and_return(true)
      end

      it { is_expected.to be_nil }
    end
  end
end
