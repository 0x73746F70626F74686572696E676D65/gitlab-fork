# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::YamlProcessor, feature_category: :pipeline_composition do
  subject(:result) { described_class.new(YAML.dump(config)).execute }

  describe 'Bridge Needs' do
    let(:config) do
      {
        build: { stage: 'build', script: 'test' },
        bridge: { stage: 'test', needs: needs }
      }
    end

    context 'when needs upstream pipeline' do
      let(:needs) { { pipeline: 'some/project' } }

      it 'creates jobs with valid specification' do
        expect(result.builds.size).to eq(2)
        expect(result.builds[0]).to eq(
          stage: "build",
          stage_idx: 1,
          name: "build",
          only: { refs: %w[branches tags] },
          options: {
            script: ["test"]
          },
          when: "on_success",
          allow_failure: false,
          job_variables: [],
          root_variables_inheritance: true,
          scheduling_type: :stage
        )
        expect(result.builds[1]).to eq(
          stage: "test",
          stage_idx: 2,
          name: "bridge",
          only: { refs: %w[branches tags] },
          options: {
            bridge_needs: { pipeline: 'some/project' }
          },
          when: "on_success",
          allow_failure: false,
          job_variables: [],
          root_variables_inheritance: true,
          scheduling_type: :stage
        )
      end
    end

    context 'when needs both job and pipeline' do
      let(:needs) { ['build', { pipeline: 'some/project' }] }

      it 'creates jobs with valid specification' do
        expect(result.builds.size).to eq(2)
        expect(result.builds[0]).to eq(
          stage: "build",
          stage_idx: 1,
          name: "build",
          only: { refs: %w[branches tags] },
          options: {
            script: ["test"]
          },
          when: "on_success",
          allow_failure: false,
          job_variables: [],
          root_variables_inheritance: true,
          scheduling_type: :stage
        )
        expect(result.builds[1]).to eq(
          stage: "test",
          stage_idx: 2,
          name: "bridge",
          only: { refs: %w[branches tags] },
          options: {
            bridge_needs: { pipeline: 'some/project' }
          },
          needs_attributes: [
            { name: "build", artifacts: true, optional: false }
          ],
          when: "on_success",
          allow_failure: false,
          job_variables: [],
          root_variables_inheritance: true,
          scheduling_type: :stage
        )
      end
    end

    context 'when needs cross projects artifacts' do
      let(:config) do
        {
          build: { stage: 'build', script: 'test' },
          test1: { stage: 'test', script: 'test', needs: needs },
          test2: { stage: 'test', script: 'test' }
        }
      end

      let(:needs) do
        [
          { job: 'build' },
          {
            project: 'some/project',
            ref: 'some/ref',
            job: 'build2',
            artifacts: true
          },
          {
            project: 'some/other/project',
            ref: 'some/ref',
            job: 'build3',
            artifacts: false
          },
          {
            project: 'project',
            ref: 'master',
            job: 'build4'
          }
        ]
      end

      it 'creates jobs with valid specification' do
        expect(result.builds.size).to eq(3)

        expect(result.builds[1]).to eq(
          stage: 'test',
          stage_idx: 2,
          name: 'test1',
          options: {
            script: ['test'],
            cross_dependencies: [
              {
                artifacts: true,
                job: 'build2',
                project: 'some/project',
                ref: 'some/ref'
              },
              {
                artifacts: false,
                job: 'build3',
                project: 'some/other/project',
                ref: 'some/ref'
              },
              {
                artifacts: true,
                job: 'build4',
                project: 'project',
                ref: 'master'
              }
            ]
          },
          needs_attributes: [
            { name: 'build', artifacts: true, optional: false }
          ],
          only: { refs: %w[branches tags] },
          when: 'on_success',
          allow_failure: false,
          job_variables: [],
          root_variables_inheritance: true,
          scheduling_type: :dag
        )
      end
    end

    context 'when needs cross projects artifacts and pipelines' do
      let(:needs) do
        [
          {
            project: 'some/project',
            ref: 'some/ref',
            job: 'build',
            artifacts: true
          },
          {
            pipeline: 'other/project'
          }
        ]
      end

      it 'returns errors' do
        expect(result.errors).to include(
          'jobs:bridge config should contain either a trigger or a needs:pipeline')
      end
    end

    context 'with invalid needs cross projects artifacts' do
      let(:config) do
        {
          build: { stage: 'build', script: 'test' },
          test: {
            stage: 'test',
            script: 'test',
            needs: {
              project: 'some/project',
              ref: 1,
              job: 'build',
              artifacts: true
            }
          }
        }
      end

      it 'returns errors' do
        expect(result.errors).to contain_exactly(
          'jobs:test:needs:need ref should be a string')
      end
    end

    describe 'with cross pipeline needs' do
      context 'when job is not present' do
        let(:config) do
          {
            rspec: {
              stage: 'test',
              script: 'rspec',
              needs: [
                { pipeline: '$UPSTREAM_PIPELINE_ID' }
              ]
            }
          }
        end

        it 'returns an error' do
          expect(result).not_to be_valid
          # This currently shows a confusing error message because a conflict of syntax
          # with upstream pipeline status mirroring: https://gitlab.com/gitlab-org/gitlab/-/issues/280853
          expect(result.errors).to include(/:needs config uses invalid types: bridge/)
        end
      end
    end

    describe 'with cross project and cross pipeline needs' do
      let(:config) do
        {
          rspec: {
            stage: 'test',
            script: 'rspec',
            needs: [
              { pipeline: '$UPSTREAM_PIPELINE_ID', job: 'test' },
              { project: 'org/the-project', ref: 'master', job: 'build', artifacts: true }
            ]
          }
        }
      end

      it 'returns a valid specification' do
        expect(result).to be_valid

        rspec = result.builds.last
        expect(rspec.dig(:options, :cross_dependencies)).to eq(
          [
            { pipeline: '$UPSTREAM_PIPELINE_ID', job: 'test', artifacts: true },
            { project: 'org/the-project', ref: 'master', job: 'build', artifacts: true }
          ])
      end
    end

    describe 'dast configuration' do
      let(:config) do
        {
          build: {
            stage: 'build',
            dast_configuration: { site_profile: 'Site profile', scanner_profile: 'Scanner profile' },
            script: 'test'
          }
        }
      end

      it 'creates a job with a valid specification' do
        expect(result.builds[0][:options]).to include(
          dast_configuration: { site_profile: 'Site profile', scanner_profile: 'Scanner profile' }
        )
      end
    end
  end

  describe 'secrets' do
    context 'on hashicorp vault' do
      let(:secrets) do
        {
          DATABASE_PASSWORD: {
            vault: 'production/db/password'
          }
        }
      end

      let(:config) { { deploy_to_production: { stage: 'deploy', script: ['echo'], secrets: secrets } } }

      it "returns secrets info" do
        secrets = result.builds.first.fetch(:secrets)

        expect(secrets).to eq({
          DATABASE_PASSWORD: {
            vault: {
              engine: { name: 'kv-v2', path: 'kv-v2' },
              path: 'production/db',
              field: 'password'
            }
          }
        })
      end
    end

    context 'on azure key vault' do
      let(:secrets) do
        {
          DATABASE_PASSWORD: {
            azure_key_vault: {
              name: 'key',
              version: 'version'
            }
          }
        }
      end

      let(:config) { { deploy_to_production: { stage: 'deploy', script: ['echo'], secrets: secrets } } }

      it "returns secrets info" do
        secrets = result.builds.first.fetch(:secrets)

        expect(secrets).to eq({
          DATABASE_PASSWORD: {
            azure_key_vault: {
              name: 'key',
              version: 'version'
            }
          }
        })
      end
    end
  end

  describe 'identity', feature_category: :secrets_management do
    let(:config) do
      {
        build: {
          stage: 'build', script: 'test',
          identity: 'google_cloud'
        }
      }
    end

    before do
      stub_saas_features(google_artifact_registry: true)
    end

    it 'includes identity-related values' do
      identity = result.builds.first.dig(:options, :identity)

      expect(identity).to eq('google_cloud')
    end
  end
end
