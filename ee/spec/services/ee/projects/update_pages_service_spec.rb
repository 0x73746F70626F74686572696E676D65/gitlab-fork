# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::UpdatePagesService, feature_category: :pages do
  let_it_be(:project) { create(:project) }

  let(:path_prefix) { nil }
  let(:build_options) { { pages: { path_prefix: path_prefix } } }
  let(:build) { create(:ci_build, :pages, project: project, options: build_options) }

  subject(:service) { described_class.new(project, build) }

  before_all do
    project.actual_limits.update!(active_versioned_pages_deployments_limit_by_namespace: 100)
  end

  before do
    stub_pages_setting(enabled: true)
  end

  context 'when path_prefix is not blank' do
    let(:path_prefix) { '/path_prefix/' }

    context 'and pages_multiple_versions is disabled for project' do
      before do
        allow(::Gitlab::Pages)
          .to receive(:multiple_versions_enabled_for?)
          .with(build.project)
          .and_return(false)
      end

      it 'does not create a new pages_deployment' do
        expect { expect(service.execute).to include(status: :error) }
          .not_to change { project.pages_deployments.count }
      end
    end

    context 'and pages_multiple_versions is enabled for project' do
      before do
        allow(::Gitlab::Pages)
          .to receive(:multiple_versions_enabled_for?)
          .with(build.project)
          .and_return(true)
      end

      it 'saves the slugiffied version of the path prefix' do
        expect { expect(service.execute).to include(status: :success) }
          .to change { project.pages_deployments.count }.by(1)

        expect(project.pages_deployments.last.path_prefix).to eq('path-prefix')
      end
    end
  end
end
