# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::Organization, feature_category: :cell do
  describe 'associations' do
    it { is_expected.to have_many(:sbom_occurrences).through(:active_projects).class_name('Sbom::Occurrence') }
    it { is_expected.to have_many(:vulnerability_exports).class_name('Vulnerabilities::Export') }
  end

  describe '#sbom_occurrences' do
    let_it_be_with_reload(:organization) { create(:organization) }

    subject(:sbom_occurrences) { organization.sbom_occurrences }

    context 'when a project is active' do
      let_it_be(:active_project) { create(:project, organization: organization) }
      let_it_be(:occurrence_from_active_project) { create(:sbom_occurrence, project: active_project) }

      it 'includes the occurrences from the project' do
        expect(sbom_occurrences).to include(occurrence_from_active_project)
      end
    end

    context 'when a project is archived' do
      let_it_be(:archived_project) { create(:project, :archived, organization: organization) }
      let_it_be(:occurrence_from_archived_project) { create(:sbom_occurrence, project: archived_project) }

      it 'does not includes the occurrences from the archived project' do
        expect(sbom_occurrences).not_to include(occurrence_from_archived_project)
      end
    end
  end
end
