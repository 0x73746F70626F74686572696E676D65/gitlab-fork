# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::UpdatePagesService, feature_category: :pages do
  let_it_be(:path_prefix) { '__pages__prefix__' }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:build_options) { { pages: { path_prefix: path_prefix } } }
  let_it_be_with_reload(:build) { create(:ci_build, :pages, project: project, options: build_options) }

  subject(:service) { described_class.new(project, build) }

  before do
    stub_pages_setting(enabled: true)

    create(:plan_limits, :default_plan, active_versioned_pages_deployments_limit_by_namespace: 100)
  end

  context 'when pages_multiple_versions is not enabled for project' do
    it 'does not save the given path prefix' do
      expect(::Gitlab::Pages)
        .to receive(:multiple_versions_enabled_for?)
        .with(build.project)
        .and_return(false)
        .at_least(:once)

      expect do
        expect(service.execute[:status]).to eq(:success)
      end.to change { project.pages_deployments.count }.by(1)

      deployment = project.pages_deployments.last

      expect(deployment.path_prefix).to be_nil
    end
  end

  context 'when pages_multiple_versions is enabled for project', :aggregate_failures do
    before do
      allow(::Gitlab::Pages)
        .to receive(:multiple_versions_enabled_for?)
        .with(build.project)
        .and_return(true)
    end

    it 'succeeds and create a new PagesDeployment' do
      expect do
        expect(service.execute[:status]).to eq(:success)
      end.to change { project.pages_deployments.count }.by(1)
    end

    it 'saves the given path prefix' do
      service.execute

      expect(project.pages_deployments.last.path_prefix).to eq(path_prefix)
    end

    it 'URL escapes the path prefix value' do
      allow(build).to receive(:pages).and_return({ path_prefix: '!' })

      service.execute

      expect(project.pages_deployments.last.path_prefix).to eq('%21')
    end
  end
end
