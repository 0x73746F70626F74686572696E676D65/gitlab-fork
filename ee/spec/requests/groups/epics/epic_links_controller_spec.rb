# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Epics::EpicLinksController do
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:parent_epic, reload: true) { create(:epic, group: group) }
  let_it_be(:epic1, reload: true) { create(:epic, group: group) }
  let_it_be(:epic2, reload: true) { create(:epic, group: group) }
  let_it_be(:user)  { create(:user) }
  let_it_be(:features_when_forbidden) { { epics: true, subepics: false } }

  before do
    sign_in(user)
  end

  shared_examples 'unlicensed subepics action' do
    before do
      stub_licensed_features(features_when_forbidden)
      group.add_developer(user)

      subject
    end

    it 'returns 403 status' do
      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'GET #index' do
    let(:features_when_forbidden) { { epics: false } }

    before do
      epic1.update!(parent: parent_epic)
    end

    subject { get group_epic_links_path(group_id: group, epic_id: parent_epic.to_param) }

    shared_examples 'avoids N+1 queries' do |threshold: 0, with_new_group: false|
      it 'executes same number of queries plus threshold', :use_sql_query_cache do
        # When with_new_group is false, the new child belong to the same group as the parent
        # When true, the new child is created in a new group
        epics_group = with_new_group ? create(:group) : group

        def get_epics
          get group_epic_links_path(group_id: group, epic_id: parent_epic.to_param, format: :json)
        end

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { get_epics }

        create(:epic, group: epics_group, parent: parent_epic)

        expect { get_epics }.not_to exceed_all_query_limit(control).with_threshold(threshold)
      end
    end

    it_behaves_like 'unlicensed subepics action'

    context 'when epics are enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when user has access to epic' do
        before do
          group.add_developer(user)

          subject
        end

        it 'returns the correct JSON response' do
          list_service_response = Epics::EpicLinks::ListService.new(parent_epic, user).execute

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq(list_service_response.as_json)
        end

        context 'with query performance' do
          before do
            create_list(:epic, 3, group: group, parent: parent_epic)
          end

          # Executes 3 extra queries to fetch the new group
          #   SELECT "saml_providers"
          #   SELECT "namespaces"
          #   SELECT "routes"
          # Executes 2 extra queries per the child to fetch its issues and epics
          # See: https://gitlab.com/gitlab-org/gitlab/-/issues/382056
          it_behaves_like 'avoids N+1 queries', threshold: 5, with_new_group: true

          context 'when child_epics_from_different_hierarchies is disabled' do
            before do
              stub_feature_flags(child_epics_from_different_hierarchies: false)
            end

            # Executes 2 extra queries to fetch group
            #   SELECT "namespaces"
            #   SELECT "routes"
            # Executes 2 extra queries per the child to fetch its issues and epics
            # See: https://gitlab.com/gitlab-org/gitlab/-/issues/382056
            it_behaves_like 'avoids N+1 queries', threshold: 4
          end
        end
      end

      context 'when user does not have access to epic' do
        it 'returns 404 status' do
          group.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)

          subject

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with children in different group hierarchies' do
        let_it_be(:other_group) { create(:group) }
        let_it_be(:other_child) { create(:epic, group: other_group, parent: parent_epic) }

        shared_examples 'returns correct response' do |children_count:|
          it 'includes only children with access' do
            subject

            list_service_response = Epics::EpicLinks::ListService.new(parent_epic, user).execute

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq(list_service_response.as_json)
            expect(list_service_response.count).to eq(children_count)
          end
        end

        it_behaves_like 'returns correct response', children_count: 2

        context 'when user has no access to the other group' do
          before do
            other_group.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
          end

          it_behaves_like 'returns correct response', children_count: 1
        end

        context 'when child_epics_from_different_hierarchies is disabled' do
          before do
            stub_feature_flags(child_epics_from_different_hierarchies: false)
          end

          it_behaves_like 'returns correct response', children_count: 1
        end
      end
    end
  end

  describe 'POST #create' do
    subject do
      reference = [epic1.to_reference(full: true)]

      post group_epic_links_path(group_id: group, epic_id: parent_epic.to_param, issuable_references: reference)
    end

    it_behaves_like 'unlicensed subepics action'

    context 'when subepics are enabled' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      context 'when user has permissions to create requested association' do
        before do
          group.add_developer(user)
        end

        it 'returns correct response for the correct issue reference' do
          subject
          list_service_response = Epics::EpicLinks::ListService.new(parent_epic, user).execute

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq('message' => nil, 'issuables' => list_service_response.as_json)
        end

        it 'updates a parent for the referenced epic' do
          expect { subject }.to change { epic1.reload.parent }.from(nil).to(parent_epic)
        end
      end

      context 'when user does not have permissions to create requested association' do
        it 'returns 403 status' do
          subject

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'does not update parent attribute' do
          expect { subject }.not_to change { epic1.reload.parent }.from(nil)
        end
      end
    end
  end

  describe 'PUT #update' do
    before do
      epic1.update!(parent: parent_epic)
      epic2.update!(parent: parent_epic)
    end

    let(:move_before_epic) { epic2 }

    subject do
      put group_epic_link_path(group_id: group, epic_id: parent_epic.to_param,
                               id: epic1.id, epic: { move_before_id:
                                                     move_before_epic.id })
    end

    it_behaves_like 'unlicensed subepics action'

    context 'when subepics are enabled' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      context 'when user has permissions to reorder epics' do
        before do
          group.add_developer(user)
        end

        it 'returns status 200' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'updates the epic position' do
          expect { subject }.to change { epic1.reload.relative_position }
        end

        context 'when move_before_id is not a sibling epic' do
          let(:move_before_epic) { create(:epic, group: group) }

          it 'returns status 404' do
            subject

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context 'when user does not have permissions to reorder epics' do
        it 'returns status 403' do
          subject

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  describe 'DELETE #destroy' do
    before do
      epic1.update!(parent: parent_epic)
    end

    let(:features_when_forbidden) { { epics: false } }

    subject { delete group_epic_link_path(group_id: group, epic_id: parent_epic.to_param, id: epic1.id) }

    it_behaves_like 'unlicensed subepics action'

    context 'when epics are enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when user has permissions to update the parent epic' do
        before do
          group.add_developer(user)
        end

        it 'returns status 200' do
          subject

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'destroys the link' do
          expect { subject }.to change { epic1.reload.parent }.from(parent_epic).to(nil)
        end
      end

      context 'when user does not have permissions to update the parent epic' do
        it 'returns status 404' do
          subject

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'does not destroy the link' do
          expect { subject }.not_to change { epic1.reload.parent }.from(parent_epic)
        end
      end

      context 'when the epic does not have any parent' do
        it 'returns status 404' do
          delete group_epic_link_path(group_id: group, epic_id: parent_epic.to_param, id: epic2.id)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'when user has permissions to update the parent epic but epics feature is disabled' do
      before do
        stub_licensed_features(epics: false)
        group.add_developer(user)
      end

      it 'does not destroy the link' do
        expect { subject }.not_to change { epic1.reload.parent }.from(parent_epic)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
