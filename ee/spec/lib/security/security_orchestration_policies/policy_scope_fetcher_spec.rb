# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicyScopeFetcher, :aggregate_failures, feature_category: :security_policy_management do
  let_it_be_with_refind(:namespace) { create(:group) }

  let_it_be_with_refind(:namespace1) { create(:group, parent: namespace) }
  let_it_be_with_refind(:namespace2) { create(:group, parent: namespace) }

  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, namespace: namespace, project: nil)
  end

  let_it_be(:project1) { create(:project, namespace: namespace) }
  let_it_be(:project2) { create(:project, namespace: namespace) }

  let_it_be_with_refind(:framework1) { create(:compliance_framework, namespace: namespace, name: 'GDPR') }
  let_it_be_with_refind(:framework2) { create(:compliance_framework, namespace: namespace, name: 'SOX') }

  let(:policy_scope) do
    {
      compliance_frameworks: [
        { id: framework1.id },
        { id: framework2.id }
      ],
      projects: {
        including: [
          { id: project1.id }
        ],
        excluding: [
          { id: project2.id }
        ]
      },
      groups: {
        including: [
          { id: namespace1.id }
        ],
        excluding: [
          { id: namespace2.id }
        ]
      }
    }
  end

  let_it_be_with_refind(:container) { namespace }
  let(:current_user) { namespace.owner }

  subject(:service) do
    described_class.new(policy_scope: policy_scope, container: container, current_user: current_user)
  end

  shared_examples 'returns policy_scope' do
    context 'when compliance_frameworks, projects and groups are present' do
      it 'returns the compliance_frameworks and projects' do
        response = service.execute

        expect(response[:compliance_frameworks]).to contain_exactly(framework1, framework2)
        expect(response[:including_projects]).to contain_exactly(project1)
        expect(response[:excluding_projects]).to contain_exactly(project2)
        expect(response[:including_groups]).to contain_exactly(namespace1)
        expect(response[:excluding_groups]).to contain_exactly(namespace2)
      end
    end

    context 'when policy_scope is empty' do
      let(:policy_scope) { nil }

      it 'returns empty result' do
        response = service.execute

        expect(response[:compliance_frameworks]).to be_empty
        expect(response[:including_projects]).to be_empty
        expect(response[:excluding_projects]).to be_empty
        expect(response[:including_groups]).to be_empty
        expect(response[:excluding_groups]).to be_empty
      end
    end

    context 'when projects are empty and groups are missing' do
      let(:policy_scope) do
        {
          compliance_frameworks: [
            { id: framework1.id },
            { id: framework2.id }
          ],
          projects: {
            including: [],
            excluding: []
          }
        }
      end

      it 'returns the compliance_frameworks' do
        response = service.execute

        expect(response[:compliance_frameworks]).to contain_exactly(framework1, framework2)
        expect(response[:including_projects]).to be_empty
        expect(response[:excluding_projects]).to be_empty
        expect(response[:including_groups]).to be_empty
        expect(response[:excluding_groups]).to be_empty
      end
    end

    context 'when groups are empty and projects are missing' do
      let(:policy_scope) do
        {
          compliance_frameworks: [
            { id: framework1.id },
            { id: framework2.id }
          ],
          groups: {
            including: [],
            excluding: []
          }
        }
      end

      it 'returns the compliance_frameworks' do
        response = service.execute

        expect(response[:compliance_frameworks]).to contain_exactly(framework1, framework2)
        expect(response[:including_projects]).to be_empty
        expect(response[:excluding_projects]).to be_empty
        expect(response[:including_groups]).to be_empty
        expect(response[:excluding_groups]).to be_empty
      end
    end

    context 'when compliance framework is not associated with the namespace' do
      let_it_be(:framework) { create(:compliance_framework) }
      let(:policy_scope) do
        {
          compliance_frameworks: [{ id: framework.id }],
          projects: { including: [], excluding: [] }
        }
      end

      it 'returns empty result' do
        response = service.execute

        expect(response[:compliance_frameworks]).to be_empty
        expect(response[:including_projects]).to be_empty
        expect(response[:excluding_projects]).to be_empty
        expect(response[:including_groups]).to be_empty
        expect(response[:excluding_groups]).to be_empty
      end
    end

    context 'when projects are not associated with the namespace' do
      let_it_be(:project1) { create(:project) }
      let_it_be(:project2) { create(:project) }
      let(:policy_scope) do
        {
          compliance_frameworks: [{ id: framework1.id }],
          projects: { including: [{ id: project1.id }], excluding: [{ id: project2.id }] }
        }
      end

      it 'returns empty projects' do
        response = service.execute

        expect(response[:compliance_frameworks]).to contain_exactly(framework1)
        expect(response[:including_projects]).to be_empty
        expect(response[:excluding_projects]).to be_empty
      end
    end

    context 'when groups are not associated with the namespace' do
      let_it_be(:namespace1) { create(:namespace) }
      let_it_be(:namespace2) { create(:namespace) }
      let(:policy_scope) do
        {
          compliance_frameworks: [{ id: framework1.id }],
          groups: { including: [{ id: namespace1.id }], excluding: [{ id: namespace2.id }] }
        }
      end

      it 'returns empty groups' do
        response = service.execute

        expect(response[:compliance_frameworks]).to contain_exactly(framework1)
        expect(response[:including_groups]).to be_empty
        expect(response[:excluding_groups]).to be_empty
      end
    end
  end

  describe '#execute' do
    context 'when container is a group' do
      it_behaves_like 'returns policy_scope'
    end

    context 'when container is a project' do
      let_it_be_with_refind(:container) { create(:project, namespace: namespace) }

      it_behaves_like 'returns policy_scope'
    end

    context 'when container is a compliance_framework' do
      let_it_be_with_refind(:container) { framework1 }

      it_behaves_like 'returns policy_scope'
    end
  end
end
