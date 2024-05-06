# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::Package do
  let(:package) { create(:generic_package) }

  subject { described_class.new(package).as_json(namespace: package.project.namespace) }

  it 'exposes correct attributes' do
    expect(subject).to include(
      :id,
      :name,
      :version,
      :package_type,
      :status,
      :_links,
      :created_at,
      :tags,
      :versions
    )
  end

  it 'exposes correct web_path in _links' do
    expect(subject[:_links][:web_path]).to match('/packages/')
  end

  context 'with a terraform_module' do
    let(:package) { create(:terraform_module_package) }

    it 'exposes correct web_path in _links' do
      expect(subject[:_links][:web_path]).to match('/terraform_module_registry/')
    end
  end

  context 'when package has no default status' do
    let(:package) { create(:package, :error) }

    it 'does not expose web_path in _links' do
      expect(subject[:_links]).not_to have_key(:web_path)
    end
  end

  context 'without build info' do
    it 'does not include pipeline attributes' do
      expect(subject).not_to include(
        :pipeline,
        :pipelines
      )
    end
  end

  context 'with build info' do
    let_it_be(:project) { create(:project) }
    let_it_be(:package) { create(:npm_package, :with_build, project: project) }
    let_it_be(:pipeline) { package.pipeline }
    let(:expected_data) do
      {
        id: pipeline.id,
        iid: pipeline.iid,
        sha: pipeline.sha,
        project_id: pipeline.project_id,
        ref: pipeline.ref,
        status: pipeline.status,
        source: pipeline.source
      }
    end

    it 'returns the pipeline' do
      expect(subject[:pipeline]).to match(a_hash_including(expected_data))
    end

    it 'returns an empty array for pipelines' do
      expect(subject[:pipelines]).to eq([])
    end
  end
end
