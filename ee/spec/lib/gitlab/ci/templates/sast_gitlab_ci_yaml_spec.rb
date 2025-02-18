# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SAST.gitlab-ci.yml', feature_category: :continuous_integration do
  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('SAST') }

  describe 'the created pipeline' do
    let(:default_branch) { 'master' }
    let(:files) { { 'README.txt' => '' } }
    let(:project) { create(:project, :custom_repo, files: files) }
    let(:user) { project.first_owner }
    let(:service) { Ci::CreatePipelineService.new(project, user, ref: 'master') }
    let(:pipeline) { service.execute(:push).payload }
    let(:build_names) { pipeline.builds.pluck(:name) }

    before do
      stub_ci_pipeline_yaml_file(template.content)
      allow_next_instance_of(Ci::BuildScheduleWorker) do |worker|
        allow(worker).to receive(:perform).and_return(true)
      end
      allow(project).to receive(:default_branch).and_return(default_branch)
    end

    context 'when project has no license' do
      context 'when SAST_DISABLED=1' do
        before do
          create(:ci_variable, project: project, key: 'SAST_DISABLED', value: '1')
        end

        it 'includes no jobs' do
          expect(build_names).to be_empty
          expect(pipeline.errors.full_messages).to match_array(['Pipeline will not run for the selected trigger. ' \
            'The rules configuration prevented any jobs from being added to the pipeline.'])
        end
      end

      context 'when SAST_EXPERIMENTAL_FEATURES is disabled for iOS projects' do
        let(:files) { { 'a.xcodeproj/x.pbxproj' => '' } }

        before do
          create(:ci_variable, project: project, key: 'SAST_EXPERIMENTAL_FEATURES', value: 'false')
        end

        it 'includes no jobs' do
          expect(build_names).to be_empty
          expect(pipeline.errors.full_messages).to match_array(['Pipeline will not run for the selected trigger. ' \
            'The rules configuration prevented any jobs from being added to the pipeline.'])
        end
      end

      context 'by default' do
        describe 'language detection' do
          using RSpec::Parameterized::TableSyntax

          where(:case_name, :files, :variables, :include_build_names) do
            'Apex'                 | { 'app.cls' => '' }                                    | {}                                         | %w[pmd-apex-sast]
            'C'                    | { 'app.c' => '' }                                      | {}                                         | %w[semgrep-sast]
            'C++'                  | { 'app.cpp' => '' }                                    | {}                                         | %w[semgrep-sast]
            'C#'                   | { 'app.cs' => '' }                                     | {}                                         | %w[semgrep-sast]
            'Elixir'               | { 'mix.exs' => '' }                                    | {}                                         | %w[sobelow-sast]
            'Elixir, nested'       | { 'a/b/mix.exs' => '' }                                | {}                                         | %w[sobelow-sast]
            'Golang'               | { 'main.go' => '' }                                    | {}                                         | %w[semgrep-sast]
            'Groovy'               | { 'app.groovy' => '' }                                 | {}                                         | %w[spotbugs-sast]
            'Java'                 | { 'app.java' => '' }                                   | {}                                         | %w[semgrep-sast]
            'Javascript'           | { 'app.js' => '' }                                     | {}                                         | %w[semgrep-sast]
            'JSX'                  | { 'app.jsx' => '' }                                    | {}                                         | %w[semgrep-sast]
            'HTML'                 | { 'index.html' => '' }                                 | {}                                         | %w[semgrep-sast]
            'Kotlin'               | { 'app.kt' => '' }                                     | {}                                         | %w[semgrep-sast]
            'Kubernetes Manifests' | { 'Chart.yaml' => '' }                                 | { 'SCAN_KUBERNETES_MANIFESTS' => 'true' }  | %w[kubesec-sast]
            'Multiple languages'   | { 'app.java' => '', 'app.js' => '', 'app.php' => '' }  | {}                                         | %w[semgrep-sast]
            'Objective C'          | { 'app.m' => '' }                                      | {}                                         | %w[semgrep-sast]
            'PHP'                  | { 'app.php' => '' }                                    | {}                                         | %w[semgrep-sast]
            'Python'               | { 'app.py' => '' }                                     | {}                                         | %w[semgrep-sast]
            'Ruby'                 | { 'config/routes.rb' => '' }                           | {}                                         | %w[semgrep-sast]
            'Scala'                | { 'app.scala' => '' }                                  | {}                                         | %w[semgrep-sast]
            'Scala'                | { 'app.sc' => '' }                                     | {}                                         | %w[semgrep-sast]
            'Swift'                | { 'app.swift' => '' }                                  | {}                                         | %w[semgrep-sast]
            'Typescript'           | { 'app.ts' => '' }                                     | {}                                         | %w[semgrep-sast]
            'Typescript JSX'       | { 'app.tsx' => '' }                                    | {}                                         | %w[semgrep-sast]
          end

          with_them do
            before do
              variables.each do |(key, value)|
                create(:ci_variable, project: project, key: key, value: value)
              end
            end

            it 'creates a pipeline with the expected jobs' do
              expect(build_names).to include(*include_build_names)
            end
          end
        end
      end
    end
  end
end
