# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::CascadeDuoFeaturesEnabledWorker, type: :worker, feature_category: :ai_abstraction_layer do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:group) { create(:group) }

  subject(:run_worker) { described_class.new.perform(group.id) }

  where(duo_features_enabled: [true, false])

  with_them do
    before do
      group.namespace_settings.update!(duo_features_enabled: duo_features_enabled)
    end

    context 'when group contains subgroups' do
      let_it_be_with_reload(:subgroup) { create(:group, parent: group) }

      it 'updates the setting on the subgroups to match the group' do
        run_worker

        expect(subgroup.namespace_settings.duo_features_enabled).to eq duo_features_enabled
      end

      context 'when subgroups contain projects' do
        let_it_be_with_reload(:subgroup_project) { create(:project, group: subgroup) }
        let_it_be(:project_setting) { create(:project_setting, project: subgroup_project) }

        it 'updates the setting on the projects to match the group' do
          run_worker

          expect(subgroup_project.duo_features_enabled).to eq duo_features_enabled
        end
      end
    end

    context 'when group contains projects' do
      let_it_be_with_reload(:group_project) { create(:project, group: group) }
      let_it_be(:project_setting) { create(:project_setting, project: group_project) }

      it 'updates the setting on the projects to match the group' do
        run_worker

        expect(group_project.duo_features_enabled).to eq duo_features_enabled
      end
    end

    context 'when group does not contain subgroups or projects' do
      it 'does not raise an error' do
        expect { run_worker }.not_to raise_error
      end
    end

    it 'avoids N+1 queries' do
      control = ActiveRecord::QueryRecorder.new do
        run_worker
      end

      new_subgroup = create(:group, parent: group)
      create(:project, group: new_subgroup)

      expect { run_worker }.not_to exceed_all_query_limit(control)
    end
  end
end
