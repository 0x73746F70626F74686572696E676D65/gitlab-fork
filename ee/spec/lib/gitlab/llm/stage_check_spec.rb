# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::StageCheck, feature_category: :ai_abstraction_layer do
  let(:feature_name) { :make_widgets }

  describe ".available?" do
    using RSpec::Parameterized::TableSyntax

    shared_examples 'expected stage check results' do
      it 'returns expected result' do
        expect(described_class.available?(container, feature_name)).to eq(result)
      end

      context 'for a project in a personal namespace' do
        let_it_be(:user) { create(:user) }
        let_it_be(:project) { create(:project, namespace: user.namespace) }

        it 'returns false' do
          expect(described_class.available?(project, feature_name)).to eq(false)
        end
      end

      context 'with an invalid feature name' do
        it 'returns false' do
          expect(described_class.available?(container, :invalid_feature_name)).to eq(false)
        end
      end

      context 'when not on a plan with ai_features licensed' do
        before do
          stub_licensed_features(ai_features: false)
        end

        it 'returns false' do
          expect(described_class.available?(container, feature_name)).to eq(false)
        end
      end

      context 'when feature is chat' do
        let(:feature_name) { :chat }

        context 'when not on a plan with ai_chat licensed' do
          before do
            stub_licensed_features(ai_chat: false)
          end

          it 'returns false' do
            expect(described_class.available?(container, feature_name)).to eq(false)
          end
        end
      end
    end

    context 'when gitlab.com', :saas do
      let_it_be_with_reload(:root_group) { create(:group_with_plan, :private, plan: :premium_plan) }
      let_it_be(:group) { create(:group, :private, parent: root_group) }
      let_it_be_with_reload(:project) { create(:project, group: group) }

      where(:container, :feature_type, :namespace_experiment_features_enabled, :result) do
        ref(:group)   | "EXPERIMENTAL" | true  | true
        ref(:group)   | "EXPERIMENTAL" | false | false
        ref(:group)   | "BETA"         | true  | true
        ref(:group)   | "BETA"         | false | false
        ref(:group)   | "GA"           | true  | true
        ref(:group)   | "GA"           | false | true
        ref(:project) | "EXPERIMENTAL" | true  | true
        ref(:project) | "EXPERIMENTAL" | false | false
        ref(:project) | "BETA"         | true  | true
        ref(:project) | "BETA"         | false | false
        ref(:project) | "GA"           | true  | true
        ref(:project) | "GA"           | false | true
      end

      with_them do
        before do
          stub_const("#{described_class}::#{feature_type}_FEATURES", [feature_name])
          stub_licensed_features(ai_features: true)
          stub_saas_features(gitlab_duo_saas_only: true)
          root_group.namespace_settings.update!(experiment_features_enabled: namespace_experiment_features_enabled)
          Gitlab::CurrentSettings.current_application_settings.update!(
            instance_level_ai_beta_features_enabled: true
          )
        end

        it_behaves_like 'expected stage check results'
      end
    end

    context 'when not gitlab.com' do
      let_it_be(:root_group) { create(:group, :private) }
      let_it_be(:group) { create(:group, :private, parent: root_group) }
      let_it_be_with_reload(:project) { create(:project, group: group) }

      where(:container, :feature_type, :instance_experiment_features_enabled, :result) do
        ref(:group)   | "EXPERIMENTAL" | true  | false
        ref(:group)   | "EXPERIMENTAL" | false | false
        ref(:group)   | "BETA"         | true  | false
        ref(:group)   | "BETA"         | false | false
        ref(:group)   | "GA"           | true  | true
        ref(:group)   | "GA"           | false | true
        ref(:project) | "EXPERIMENTAL" | true  | false
        ref(:project) | "EXPERIMENTAL" | false | false
        ref(:project) | "BETA"         | true  | false
        ref(:project) | "BETA"         | false | false
        ref(:project) | "GA"           | true  | true
        ref(:project) | "GA"           | false | true
      end

      with_them do
        before do
          stub_const("#{described_class}::#{feature_type}_FEATURES", [feature_name])
          stub_licensed_features(ai_features: true)
          Gitlab::CurrentSettings.current_application_settings.update!(
            instance_level_ai_beta_features_enabled: instance_experiment_features_enabled
          )
        end

        it_behaves_like 'expected stage check results'
      end
    end
  end
end
