# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::EE::API::Entities::Project, feature_category: :shared do
  let_it_be(:project) { create(:project) }

  let(:options) { {} }
  let(:developer) { create(:user, developer_of: project) }

  let(:entity) do
    ::API::Entities::Project.new(project, options)
  end

  subject { entity.as_json }

  context 'compliance_frameworks' do
    context 'when project has a compliance framework' do
      let(:project) { create(:project, :with_sox_compliance_framework) }

      it 'is an array containing a single compliance framework' do
        expect(subject[:compliance_frameworks]).to contain_exactly('SOX')
      end
    end

    context 'when project has no compliance framework' do
      let(:project) { create(:project) }

      it 'is empty array when project has no compliance framework' do
        expect(subject[:compliance_frameworks]).to eq([])
      end
    end
  end

  describe 'ci_restrict_pipeline_cancellation_role' do
    let(:options) { { current_user: current_user } }

    context 'when user has maintainer permission or above' do
      let(:current_user) { project.owner }

      context 'when available' do
        before do
          mock_available
        end

        it { expect(subject[:ci_restrict_pipeline_cancellation_role]).to eq 'developer' }
      end

      context 'when not available' do
        it { expect(subject[:ci_restrict_pipeline_cancellation_role]).to be nil }
      end
    end

    context 'when user permission is below maintainer' do
      let(:current_user) { developer }

      context 'when available' do
        before do
          mock_available
        end

        it { expect(subject[:ci_restrict_pipeline_cancellation_role]).to be nil }
      end

      context 'when not available' do
        it { expect(subject[:ci_restrict_pipeline_cancellation_role]).to be nil }
      end
    end

    def mock_available
      allow_next_instance_of(Ci::ProjectCancellationRestriction) do |cr|
        allow(cr).to receive(:feature_available?).and_return(true)
      end
    end
  end
end
