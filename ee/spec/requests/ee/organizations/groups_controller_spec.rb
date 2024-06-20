# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Organizations::GroupsController, feature_category: :cell do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public, organization: organization) }

  describe 'DELETE #destroy' do
    subject(:gitlab_request) { delete groups_organization_path(organization, id: group.to_param) }

    before_all do
      group.add_owner(user)
    end

    context 'when authenticated user can admin the group' do
      before do
        sign_in(user)
      end

      context 'when subscription is linked to the group', :saas do
        let_it_be(:group) do
          create(:group_with_plan, plan: :ultimate_plan, owners: user, organization: organization)
        end

        it 'returns active subscription error' do
          gitlab_request

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq(_('This group is linked to a subscription'))
        end
      end

      context 'when delayed deletion feature is available' do
        before do
          stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
        end

        context 'when mark for deletion succeeds' do
          it 'marks the group for delayed deletion' do
            expect { gitlab_request }.to change { group.reload.marked_for_deletion? }.from(false).to(true)
          end

          it 'does not immediately delete the group' do
            Sidekiq::Testing.fake! do
              expect { gitlab_request }.not_to change { GroupDestroyWorker.jobs.size }
            end
          end

          it 'schedules the group for deletion' do
            gitlab_request

            message = format("'%{group_name}' has been scheduled for removal on", group_name: group.name)
            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['message']).to include(message)
          end
        end

        context 'when mark for deletion fails' do
          let(:error) { 'error' }

          before do
            allow(::Groups::MarkForDeletionService).to receive_message_chain(:new, :execute)
                                                         .and_return({ status: :error, message: error })
          end

          it 'does not mark the group for deletion' do
            expect { gitlab_request }.not_to change { group.reload.marked_for_deletion? }.from(false)
          end

          it 'renders the error' do
            gitlab_request

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
            expect(json_response['message']).to include(error)
          end
        end

        context 'when group is already marked for deletion' do
          before do
            create(:group_deletion_schedule, group: group, marked_for_deletion_on: Date.current)
          end

          context 'when permanently_remove param is set' do
            it 'deletes the group immediately' do
              expect(GroupDestroyWorker).to receive(:perform_async)

              delete groups_organization_path(organization, id: group.to_param, permanently_remove: true)

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response['message']).to include "Group '#{group.name}' is being deleted."
            end
          end

          context 'when permanently_remove param is not set' do
            it 'does nothing' do
              gitlab_request

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
              expect(json_response['message']).to include "Group has been already marked for deletion"
            end
          end
        end
      end

      context 'when delayed deletion feature is not available' do
        before do
          stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
        end

        it 'immediately schedules a group destroy' do
          Sidekiq::Testing.fake! do
            expect { gitlab_request }.to change { GroupDestroyWorker.jobs.size }.by(1)
          end
        end

        it 'immediately deletes the group' do
          gitlab_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['message']).to include "Group '#{group.name}' is being deleted."
        end
      end
    end

    context 'when authenticated user cannot admin the group' do
      before do
        sign_in(create(:user))
      end

      it 'returns 404' do
        gitlab_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the group does not exist in the organization' do
      let_it_be(:group) { create(:group, :public, owners: user) }

      before do
        sign_in(user)
      end

      it_behaves_like 'organization - not found response'
    end
  end
end
