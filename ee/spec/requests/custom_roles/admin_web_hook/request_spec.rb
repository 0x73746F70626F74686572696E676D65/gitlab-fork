# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_web_hook custom role', feature_category: :webhooks do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:role) { create(:member_role, :guest, :admin_web_hook, namespace: group) }

  before do
    stub_licensed_features(custom_roles: true)
    sign_in(user)
  end

  shared_examples 'HooksController' do
    describe '#index' do
      it 'allows access' do
        get index_path

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe '#edit' do
      it 'allows access' do
        get edit_path

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe '#create' do
      it 'allows access' do
        post create_path, params: { hook: { url: 'http://example.test/' } }

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end

    describe '#update' do
      it 'allows access' do
        patch update_path, params: { hook: { name: 'Test' } }

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end

    describe '#destroy' do
      it 'allows access' do
        delete destroy_path

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end

    describe '#test' do
      it 'allows access' do
        stub_request(:post, 'http://example.test/')

        post test_path

        expect(response).to have_gitlab_http_status(:redirect)
      end
    end
  end

  describe Projects::HooksController do
    let_it_be(:membership) { create(:project_member, :guest, member_role: role, user: user, project: project) }
    let_it_be(:project_hook) { create(:project_hook, project: project, url: 'http://example.test/') }

    let(:hook) { create(:project_hook, project: project) }

    let(:index_path) { project_hooks_path(project) }
    let(:edit_path) { edit_project_hook_path(project, project_hook) }
    let(:create_path) { project_hooks_path(project) }
    let(:update_path) { project_hook_path(project, project_hook) }
    let(:destroy_path) { project_hook_path(project, hook) }
    let(:test_path) { test_project_hook_path(project, project_hook) }

    it_behaves_like 'HooksController'
  end

  describe Groups::HooksController do
    let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, group: group) }
    let_it_be(:group_hook) { create(:group_hook, group: group, url: 'http://example.test/') }

    let(:hook) { create(:group_hook, group: group) }

    let(:index_path) { group_hooks_path(group) }
    let(:edit_path) { edit_group_hook_path(group, group_hook) }
    let(:create_path) { group_hooks_path(group) }
    let(:update_path) { group_hook_path(group, group_hook) }
    let(:destroy_path) { group_hook_path(group, hook) }
    let(:test_path) { test_group_hook_path(group, group_hook) }

    it_behaves_like 'HooksController'
  end
end
