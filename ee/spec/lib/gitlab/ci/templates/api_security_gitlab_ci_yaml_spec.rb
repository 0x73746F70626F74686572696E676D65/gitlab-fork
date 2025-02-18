# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'API-Security.gitlab-ci.yml', feature_category: :continuous_integration do
  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('API-Security') }

  specify { expect(template).not_to be_nil }

  describe 'the template file' do
    let(:template_filename) { Rails.root.join("lib/gitlab/ci/templates/" + template.full_name) }
    let(:contents) { File.read(template_filename) }
    let(:production_registry) { 'APISEC_IMAGE: api-security' }
    let(:staging_registry) { 'APISEC_IMAGE: api-fuzzing-src' }

    # Make sure future changes to the template use the production container registry.
    #
    # The API Security template is developed against a dev container registry.
    # The registry is switched when releasing new versions. The difference in
    # names between development and production is also quite small making it
    # easy to miss during review.
    it 'uses the production repository' do
      expect(contents.include?(production_registry)).to be true
    end

    it "doesn't use the staging repository" do
      expect(contents.include?(staging_registry)).to be false
    end
  end

  describe 'the created pipeline' do
    let(:default_branch) { 'master' }
    let(:pipeline_branch) { default_branch }
    let_it_be(:project) { create(:project, :custom_repo, files: { 'README.txt' => '' }) }

    let(:user) { project.first_owner }
    let(:service) { Ci::CreatePipelineService.new(project, user, ref: pipeline_branch) }
    let(:pipeline) { service.execute(:push).payload }
    let(:build_names) { pipeline.builds.pluck(:name) }

    before do
      allow_next_instance_of(Ci::BuildScheduleWorker) do |worker|
        allow(worker).to receive(:perform).and_return(true)
      end

      allow(project).to receive(:default_branch).and_return(default_branch)
    end

    context 'when no stages' do
      before do
        stub_ci_pipeline_yaml_file(template.content)
      end

      context 'when project has no stages' do
        it 'includes no jobs' do
          expect(build_names).to be_empty
        end
      end
    end

    context 'when stages includes dast' do
      let(:ci_pipeline_yaml) { "stages: [\"dast\"]\n" }

      before do
        stub_ci_pipeline_yaml_file(ci_pipeline_yaml + template.content)
      end

      context 'when project has no license' do
        before do
          create(:ci_variable, project: project, key: 'APISEC_HAR', value: 'testing.har')
          create(:ci_variable, project: project, key: 'APISEC_TARGET_URL', value: 'http://example.com')
        end

        it 'includes job to display error' do
          expect(build_names).to match_array(%w[api_security])
        end
      end

      context 'when project has Ultimate license' do
        before do
          stub_licensed_features(dast: true)
        end

        context 'by default' do
          it 'includes a job' do
            expect(build_names).to match_array(%w[api_security])
          end
        end

        context 'when APISEC_DISABLED=1' do
          before do
            create(:ci_variable, project: project, key: 'APISEC_DISABLED', value: '1')
            create(:ci_variable, project: project, key: 'APISEC_HAR', value: 'testing.har')
            create(:ci_variable, project: project, key: 'APISEC_TARGET_URL', value: 'http://example.com')
          end

          it 'includes no jobs' do
            expect(build_names).to be_empty
            expect(pipeline.errors.full_messages).to match_array(['Pipeline will not run for the selected trigger. ' \
              'The rules configuration prevented any jobs from being added to the pipeline.'])
          end
        end

        context 'when CI_GITLAB_FIPS_MODE=false' do
          let(:build_api_security) { pipeline.builds.find_by(name: 'api_security') }
          let(:build_variables) { build_api_security.variables.pluck(:key, :value) }

          before do
            create(:ci_variable, project: project, key: 'CI_GITLAB_FIPS_MODE', value: 'false')
          end

          it 'sets APISEC_IMAGE_SUFFIX to ""' do
            expect(build_variables).to be_include(['APISEC_IMAGE_SUFFIX', ''])
          end
        end

        context 'when CI_GITLAB_FIPS_MODE=true' do
          let(:build_api_security) { pipeline.builds.find_by(name: 'api_security') }
          let(:build_variables) { build_api_security.variables.pluck(:key, :value) }

          before do
            create(:ci_variable, project: project, key: 'CI_GITLAB_FIPS_MODE', value: 'true')
          end

          it 'sets APISEC_IMAGE_SUFFIX to "-fips"' do
            expect(build_variables).to be_include(['APISEC_IMAGE_SUFFIX', '-fips'])
          end
        end
      end
    end
  end
end
