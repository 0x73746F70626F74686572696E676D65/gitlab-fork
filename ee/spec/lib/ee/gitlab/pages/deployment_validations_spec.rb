# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitlab::Pages::DeploymentValidations, feature_category: :pages do
  let_it_be(:group) { create(:group, :nested, max_pages_size: 200) }
  let_it_be(:project) { create(:project, :repository, namespace: group, max_pages_size: 250) }

  let(:build_options) { {} }
  let(:build) { create(:ci_build, :pages, project: project, options: build_options) }

  let(:metadata_entry) do
    instance_double(
      ::Gitlab::Ci::Build::Artifacts::Metadata::Entry,
      entries: [],
      total_size: 50.megabyte
    )
  end

  subject(:validations) { described_class.new(project, build) }

  before_all do
    project.actual_limits.update!(active_versioned_pages_deployments_limit_by_namespace: 100)
  end

  before do
    stub_pages_setting(enabled: true)

    allow(build)
      .to receive(:artifacts_metadata_entry)
      .and_return(metadata_entry)
  end

  shared_examples "valid pages deployment" do
    specify do
      expect(validations).to be_valid
    end
  end

  shared_examples "invalid pages deployment" do |message:|
    specify do
      expect(validations).not_to be_valid
      expect(validations.errors.full_messages).to include(message)
    end
  end

  describe "maximum pages artifacts size" do
    context "when pages_size_limit feature is available" do
      before do
        stub_licensed_features(pages_size_limit: true)
      end

      context "when size is below the limit" do
        before do
          allow(metadata_entry).to receive(:total_size).and_return(249.megabyte)
        end

        include_examples "valid pages deployment"
      end

      context "when size is above the limit" do
        before do
          allow(metadata_entry).to receive(:total_size).and_return(251.megabyte)
        end

        include_examples "invalid pages deployment",
          message: "artifacts for pages are too large: 263192576"
      end
    end

    context "when pages_size_limit feature is not available" do
      before do
        stub_licensed_features(pages_size_limit: false)
      end

      context "when size is below the limit" do
        before do
          allow(metadata_entry).to receive(:total_size).and_return(99.megabyte)
        end

        include_examples "valid pages deployment"
      end

      context "when size is above the limit" do
        before do
          allow(metadata_entry).to receive(:total_size).and_return(101.megabyte)
        end

        include_examples "invalid pages deployment",
          message: "artifacts for pages are too large: 105906176"
      end
    end
  end

  context "when validating multiple deployments limit" do
    let(:limit) { 2 }
    let(:path_prefix) { "other_prefix" }
    let(:build_options) { { pages: { path_prefix: path_prefix } } }

    before do
      allow(::Gitlab::Pages)
        .to receive(:multiple_versions_enabled_for?)
        .and_return(true)

      project.actual_limits.update!(active_versioned_pages_deployments_limit_by_namespace: limit)
    end

    include_examples "valid pages deployment"

    context "when overuse is from the same project" do
      before do
        limit.times do |n|
          create(:pages_deployment, project: project, path_prefix: "#{path_prefix}_#{n}")
        end
      end

      include_examples "invalid pages deployment",
        message: "Namespace reached its allowed limit of 2 extra deployments"
    end

    context "when overuse is from multiple projects" do
      before do
        (limit - 1).times do |n|
          create(:pages_deployment, project: project, path_prefix: "#{path_prefix}_#{n}")
        end

        namespace = project.root_ancestor
        other_project = create(:project, group: namespace)
        create(:pages_deployment, project: other_project, path_prefix: path_prefix)
      end

      include_examples "invalid pages deployment",
        message: "Namespace reached its allowed limit of 2 extra deployments"
    end
  end

  context "for multiple deployments is enabled validation" do
    context "when multiple deployments is enabled" do
      before do
        allow(::Gitlab::Pages)
          .to receive(:multiple_versions_enabled_for?)
          .with(build.project)
          .and_return(true)
      end

      context "and path prefix is empty" do
        let(:build_options) { { pages: { path_prefix: "" } } }

        include_examples "valid pages deployment"
      end

      context "and path prefix is not empty" do
        let(:build_options) { { pages: { path_prefix: "prefix" } } }

        include_examples "valid pages deployment"
      end
    end

    context "when multiple deployments is disabled" do
      before do
        allow(::Gitlab::Pages)
          .to receive(:multiple_versions_enabled_for?)
            .with(build.project)
            .and_return(false)
      end

      context "and path prefix is empty" do
        let(:build_options) { { pages: { path_prefix: "" } } }

        include_examples "valid pages deployment"
      end

      context "and path prefix is not empty" do
        let_it_be(:build_options) { { pages: { path_prefix: "prefix" } } }

        include_examples "invalid pages deployment",
          message: <<~MESSAGE.squish
          Configuring path_prefix is only allowed when using multiple pages deployments per project,
          which is disabled for your project.
          MESSAGE
      end
    end
  end
end
