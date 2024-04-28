# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SsoController, feature_category: :system_access do
  let(:user) { create(:user) }
  let(:group) { create(:group, :private, name: 'our-group') }

  before do
    stub_licensed_features(group_saml: true)
    allow(Devise).to receive(:omniauth_providers).and_return(%i[group_saml])
    sign_in(user)
  end

  context 'SAML configured' do
    let!(:saml_provider) { create(:saml_provider, group: group) }

    it 'has status 200' do
      get :saml, params: { group_id: group }

      expect(response).to have_gitlab_http_status(:ok)
    end

    it 'malicious redirect parameter falls back to group_path' do
      get :saml, params: { group_id: group, redirect: '///malicious-url' }

      expect(response).to have_gitlab_http_status(:ok)
      expect(assigns[:redirect_path]).to eq(group_path(group))
    end

    it 'passes group name to the view' do
      get :saml, params: { group_id: group }

      expect(assigns[:group_name]).to eq 'our-group'
    end

    context 'unlinking user' do
      before do
        create(:group_saml_identity, saml_provider: saml_provider, user: user)
        user.update!(provisioned_by_group: saml_provider.group)
      end

      it 'allows account unlinking' do
        expect do
          delete :unlink, params: { group_id: group }
        end.to change { Identity.count }.by(-1)
      end

      context 'with block_password_auth_for_saml_users feature flag switched off' do
        before do
          stub_feature_flags(block_password_auth_for_saml_users: false)
        end

        it 'does not sign out user provisioned by this group' do
          delete :unlink, params: { group_id: group }

          expect(response).to redirect_to(profile_account_path)
        end
      end

      context 'with block_password_auth_for_saml_users feature flag switched on' do
        before do
          stub_feature_flags(block_password_auth_for_saml_users: true)
        end

        it 'signs out user provisioned by this group' do
          delete :unlink, params: { group_id: group }

          expect(subject.current_user).to eq(nil)
        end
      end
    end

    context 'when SAML is disabled for the group' do
      before do
        saml_provider.update!(enabled: false)
      end

      it 'renders 404' do
        get :saml, params: { group_id: group }

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'still allows account unlinking' do
        create(:group_saml_identity, saml_provider: saml_provider, user: user)

        expect do
          delete :unlink, params: { group_id: group }
        end.to change { Identity.count }.by(-1)
      end
    end

    context 'when SAML trial has expired' do
      before do
        create(:group_saml_identity, saml_provider: saml_provider, user: user)
        stub_licensed_features(group_saml: false)
      end

      it 'DELETE /unlink still allows account unlinking' do
        expect do
          delete :unlink, params: { group_id: group }
        end.to change { Identity.count }.by(-1)
      end

      it 'GET /saml renders 404' do
        get :saml, params: { group_id: group }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is not signed in' do
      it 'acts as route not found' do
        sign_out(user)

        get :saml, params: { group_id: group }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when group has moved' do
      let(:redirect_route) { group.redirect_routes.create!(path: 'old-path') }

      it 'redirects to new location' do
        get :saml, params: { group_id: redirect_route.path }

        expect(response).to redirect_to(sso_group_saml_providers_path(group))
      end
    end

    context 'when current user has a SAML provider configured' do
      let(:saml_provider) { create(:saml_provider, group: group, enforced_sso: true) }
      let(:identity) { create(:group_saml_identity, saml_provider: saml_provider) }

      before do
        sign_out(user)
        sign_in(identity.user)
      end

      it 'renders `devise_empty` template' do
        get :saml, params: { group_id: group }

        expect(response).to render_template('devise_empty')
      end
    end

    context 'when current user does not have a SAML provider configured' do
      it 'renders `devise` template' do
        get :saml, params: { group_id: group }

        expect(response).to render_template('devise')
      end
    end
  end

  context 'saml_provider is unconfigured for the group' do
    context 'when user cannot configure Group SAML' do
      it 'renders 404' do
        get :saml, params: { group_id: group }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user can admin group_saml' do
      before do
        group.add_owner(user)
      end

      it 'redirects to the Group SAML config page' do
        get :saml, params: { group_id: group }

        expect(response).to redirect_to(group_saml_providers_path)
      end

      it 'sets a flash message explaining that setup is required' do
        get :saml, params: { group_id: group }

        expect(flash[:notice]).to match(/not been configured/)
      end
    end
  end

  context 'group does not exist' do
    it 'renders 404' do
      get :saml, params: { group_id: 'not-a-group' }

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when user is not signed in' do
      it 'acts as route not found' do
        sign_out(user)

        get :saml, params: { group_id: 'not-a-group' }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
