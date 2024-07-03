# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Members, :aggregate_failures, :api, feature_category: :subscription_management do
  describe 'GET /internal/gitlab_subscriptions/namespaces/:id/owners', :saas do
    let_it_be(:namespace) { create(:group) }
    let(:namespace_id) { namespace.id }
    let(:owners_path) { "/internal/gitlab_subscriptions/namespaces/#{namespace_id}/owners" }

    context 'when unauthenticated' do
      it 'returns authentication error' do
        get api(owners_path)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as user' do
      it 'returns authentication error' do
        get api(owners_path, create(:user))

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when authenticated as admin' do
      let_it_be(:admin) { create(:admin) }

      subject(:get_owners) do
        get api(owners_path, admin, admin_mode: true)
      end

      context 'when the namespace cannot be found' do
        let(:namespace_id) { -1 }

        it 'returns an error response' do
          get_owners

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Group Namespace Not Found')
        end
      end

      context 'when the namespace does not have any owners' do
        it 'returns an empty response' do
          get_owners

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to be_empty
        end
      end

      context 'when the namespace has owners and other members' do
        let_it_be(:owner_1) { create(:user) }
        let_it_be(:owner_2) { create(:user) }
        let_it_be(:maintainer) { create(:user) }
        let_it_be(:guest) { create(:user) }

        let_it_be(:sub_group_owner) { create(:user) }
        let_it_be(:sub_group) { create(:group, parent: namespace) }

        before_all do
          namespace.add_owner(owner_1)
          namespace.add_owner(owner_2)

          namespace.add_maintainer(maintainer)
          namespace.add_guest(guest)

          sub_group.add_owner(sub_group_owner)
        end

        it 'returns only direct owners of the namespace' do
          expected_response = [
            {
              'user' => { 'id' => owner_1.id, 'username' => a_kind_of(String), 'name' => a_kind_of(String) },
              'access_level' => 50,
              'notification_email' => a_kind_of(String)
            },
            {
              'user' => { 'id' => owner_2.id, 'username' => a_kind_of(String), 'name' => a_kind_of(String) },
              'access_level' => 50,
              'notification_email' => a_kind_of(String)
            }
          ]

          expected_pagination_headers = {
            'X-Per-Page' => '20',
            'X-Page' => '1',
            'X-Next-Page' => '',
            'X-Prev-Page' => '',
            'X-Total' => '2',
            'X-Total-Pages' => '1'
          }

          get_owners

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.headers).to match(hash_including(expected_pagination_headers))

          expect(json_response.count).to eq(2)
          expect(json_response).to match_array(expected_response)
        end

        context 'when the owner is inactive' do
          before do
            owner_2.block!
          end

          it 'does not return inactive users' do
            get_owners

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response.count).to eq(1)
            expect(json_response.first['user']['id']).to eq(owner_1.id)
          end
        end
      end
    end
  end
end
