# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Ci::RetryJobService, feature_category: :continuous_integration do
  let_it_be(:user) { create(:user) }

  let(:pipeline) { create(:ci_pipeline, project: project) }
  let(:build) { create(:ci_build, :success, pipeline: pipeline) }

  subject(:service) { described_class.new(project, user) }

  before do
    stub_not_protect_default_branch

    project.add_developer(user)
  end

  it_behaves_like 'restricts access to protected environments' do
    subject { service.execute(build)[:job] }
  end

  describe '#clone!' do
    context 'when user has ability to execute build' do
      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:project) { create(:project, namespace: namespace, creator: user) }

      let(:new_build) { service.clone!(build) }

      context 'dast' do
        let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project) }
        let_it_be(:dast_scanner_profile) { create(:dast_scanner_profile, project: project) }

        before do
          build.update!(dast_site_profile: dast_site_profile, dast_scanner_profile: dast_scanner_profile)
        end

        it 'clones the profile associations', :aggregate_failures do
          expect_next_instance_of(Ci::CopyCrossDatabaseAssociationsService) do |service|
            expect(service).to receive(:execute).with(build, Ci::Build).and_call_original
          end

          new_build.reload

          expect(new_build.dast_site_profile).to eq(dast_site_profile)
          expect(new_build.dast_scanner_profile).to eq(dast_scanner_profile)
          expect(new_build).not_to be_failed
        end
      end

      context 'when build has secrets' do
        let(:secrets) do
          {
            'DATABASE_PASSWORD' => {
              'vault' => {
                'engine' => { 'name' => 'kv-v2', 'path' => 'kv-v2' },
                'path' => 'production/db',
                'field' => 'password'
              }
            }
          }
        end

        before do
          build.update!(secrets: secrets)
        end

        it 'clones secrets' do
          expect(new_build.secrets).to eq(secrets)
        end
      end

      it_behaves_like 'authorizing CI jobs' do
        subject { new_build }
      end
    end
  end

  describe '#execute' do
    let(:new_build) { service.execute(build)[:job] }

    context 'when the CI quota is exceeded' do
      let_it_be(:namespace) { create(:namespace, :with_used_build_minutes_limit) }
      let_it_be(:project) { create(:project, namespace: namespace, creator: user) }

      context 'when there are no runners available' do
        it { expect(new_build).not_to be_failed }
      end

      context 'when shared runners are available' do
        let_it_be(:runner) { create(:ci_runner, :instance, :online) }

        it 'fails the build' do
          expect(new_build).to be_failed
          expect(new_build.failure_reason).to eq('ci_quota_exceeded')
        end

        context 'with private runners' do
          let_it_be(:private_runner) do
            create(:ci_runner, :project, :online, projects: [project])
          end

          it { expect(new_build).not_to be_failed }
        end
      end
    end
  end
end
