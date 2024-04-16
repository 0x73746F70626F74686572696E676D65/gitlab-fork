# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ProjectMembersController, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let(:group) { create(:group, :public) }
  let(:project) { create(:project, :public, namespace: group) }
  let(:project_member) { create(:project_member, source: project) }

  before do
    group.add_owner(user)
    sign_in(user)
  end

  describe 'GET /*namespace_id/:project_id/-/project_members' do
    subject(:make_request) do
      get namespace_project_project_members_path(group, project), params: param
    end

    let(:param) { {} }

    context 'with member pending promotions' do
      let!(:pending_member_approvals) do
        create_list(:member_approval, 2, :for_project_member, member_namespace: project.project_namespace)
      end

      context 'with member_promotion management feature enabled' do
        before do
          stub_feature_flags(member_promotion_management: true)
          stub_application_setting(enable_member_promotion_management: true)
        end

        context 'when user can admin project' do
          it 'assigns @pending_promotion_members' do
            make_request
            expect(assigns(:pending_promotion_members)).to match_array(pending_member_approvals)
          end

          context 'with pagination' do
            let(:param) { { promotion_requests_page: 2 } }

            it 'paginates @pending_promotion_members correctly' do
              group.add_owner(user)
              stub_const("EE::#{described_class}::MEMBER_PER_PAGE_LIMIT", 1)

              make_request
              expect(assigns(:pending_promotion_members).size).to eq(1)
              expect(assigns(:pending_promotion_members)).to contain_exactly(pending_member_approvals.second)
            end
          end
        end

        context 'when user cannot admin project' do
          it 'does not assigns @pending_promotion_members' do
            user = create(:user)
            sign_in(user)
            project.add_developer(user)

            make_request

            expect(assigns(:pending_promotion_members)).to eq(nil)
          end
        end
      end

      context 'with member_promotion management feature disabled' do
        before do
          stub_feature_flags(member_promotion_management: false)
        end

        it 'assigns @pending_promotion_members be empty' do
          make_request

          expect(assigns(:pending_promotion_members)).to be_empty
        end
      end
    end
  end
end
