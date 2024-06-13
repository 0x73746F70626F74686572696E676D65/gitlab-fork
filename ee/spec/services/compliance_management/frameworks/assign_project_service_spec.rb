# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Frameworks::AssignProjectService, feature_category: :compliance_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:framework) { create(:compliance_framework, namespace: group) }

    let(:params) { { framework: framework.id } }
    let(:error_message) { 'Failed to assign the framework to the project' }

    let(:service) { described_class.new(project, user, params) }

    subject(:update_framework) { service.execute }

    shared_examples 'no framework update' do
      it 'does not update the framework' do
        expect { update_framework }.not_to change { project.reload.compliance_management_frameworks.to_a }
      end

      it 'does not publish Projects::ComplianceFrameworkChangedEvent' do
        expect { update_framework }.not_to publish_event(::Projects::ComplianceFrameworkChangedEvent)
      end
    end

    shared_examples 'framework update' do
      it 'updates the framework' do
        expect { update_framework }.to change {
          project.reload.compliance_management_frameworks
        }.from(old_framework).to([framework])
      end

      it 'publishes Projects::ComplianceFrameworkChangedEvent' do
        expect { update_framework }
          .to publish_event(::Projects::ComplianceFrameworkChangedEvent)
                .with(project_id: project.id, compliance_framework_id: framework.id, event_type: 'added')
      end
    end

    context 'when compliance framework feature is available' do
      context 'when user can admin compliance framework for the project' do
        before do
          allow(service).to receive(:can?).with(user, :admin_compliance_framework, project).and_return(true)
        end

        context 'when assigning a compliance framework to a project' do
          context 'when no framework is assigned' do
            let(:old_framework) { [] }

            it_behaves_like 'framework update'
          end

          context 'when a framework is assigned' do
            let_it_be(:other_framework) { create(:compliance_framework, name: 'other fr', namespace: group) }

            let(:old_framework) { [other_framework] }

            before do
              create(:compliance_framework_project_setting,
                project: project, compliance_management_framework: other_framework)
            end

            it_behaves_like 'framework update'
          end
        end

        context 'when framework param is invalid' do
          let(:params) { { framework: non_existing_record_id } }

          it_behaves_like 'no framework update'

          it 'returns an error response' do
            response = update_framework

            expect(response).to be_error
            expect(response.message).to eq(error_message)
          end
        end

        context 'when unassigning a framework' do
          let(:params) { { framework: nil } }

          context 'when no framework is assigned' do
            it_behaves_like 'no framework update'
          end

          context 'when a framework is assigned' do
            before do
              create(:compliance_framework_project_setting,
                project: project, compliance_management_framework: framework)
            end

            it 'unassigns a framework from a project' do
              expect { update_framework }.to change {
                project.reload.compliance_management_frameworks
              }.from([framework]).to([])
            end

            it 'publishes Projects::ComplianceFrameworkChangedEvent with removed event type' do
              expect { update_framework }
                .to publish_event(::Projects::ComplianceFrameworkChangedEvent)
                .with(project_id: project.id, compliance_framework_id: framework.id, event_type: 'removed')
            end
          end
        end
      end

      context 'when user cannot admin compliance framework for the project' do
        before do
          allow(service).to receive(:can?).with(user, :admin_compliance_framework, project).and_return(false)
        end

        it_behaves_like 'no framework update'

        it 'returns an error response' do
          response = update_framework

          expect(response).to be_error
          expect(response.message).to eq(error_message)
        end
      end
    end

    context 'when compliance framework feature is not available' do
      before do
        stub_licensed_features(compliance_framework: false)
      end

      before_all do
        group.add_owner(user)
      end

      it_behaves_like 'no framework update'

      it 'returns an error response' do
        response = update_framework

        expect(response).to be_error
        expect(response.message).to eq(error_message)
      end
    end
  end
end
