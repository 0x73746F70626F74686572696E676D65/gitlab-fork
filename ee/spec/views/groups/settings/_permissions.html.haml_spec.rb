# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/_permissions.html.haml', :saas, feature_category: :code_suggestions do
  let_it_be(:group) { build(:group, namespace_settings: build(:namespace_settings)) }

  before do
    assign(:group, group)
    allow(view).to receive(:can?).and_return(true)
    allow(view).to receive(:current_user).and_return(build(:user))
  end

  context 'for duo features enabled' do
    before do
      allow(group).to receive(:licensed_ai_features_available?).and_call_original
    end

    context 'when licensed ai features is not available' do
      it 'renders nothing' do
        allow(group).to receive(:licensed_ai_features_available?).and_return(false)

        render

        expect(rendered).to render_template('groups/settings/_duo_features_enabled')
        expect(rendered).not_to have_content('GitLab Duo features')
      end
    end

    context 'when licensed ai features are available' do
      it 'renders the experiment settings' do
        allow(group).to receive(:licensed_ai_features_available?).and_return(true)

        render

        expect(rendered).to render_template('groups/settings/_duo_features_enabled')
        expect(rendered).to have_content('GitLab Duo features')
      end
    end
  end

  context 'for auto assign duo pro seats' do
    context 'when on SM' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'renders nothing' do
        render

        expect(rendered).to render_template('groups/settings/_auto_assign_duo_pro')
        expect(rendered).not_to have_content('Automatic assignment of GitLab Duo Pro seats')
      end
    end

    context 'when on .com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(auto_assign_gitlab_duo_pro_seats: false, thing: group)
        end

        it 'renders nothing' do
          render

          expect(rendered).to render_template('groups/settings/_auto_assign_duo_pro')
          expect(rendered).not_to have_content('Automatic assignment of GitLab Duo Pro seats')
        end
      end

      context 'when group is not a root' do
        before do
          allow(group).to receive(:root?).and_return(false)
        end

        it 'renders nothing' do
          render

          expect(rendered).to render_template('groups/settings/_auto_assign_duo_pro')
          expect(rendered).not_to have_content('Automatic assignment of GitLab Duo Pro seats')
        end
      end

      context 'when group does not have the add-on purchased' do
        it 'renders nothing' do
          render

          expect(rendered).to render_template('groups/settings/_auto_assign_duo_pro')
          expect(rendered).not_to have_content('Automatic assignment of GitLab Duo Pro seats')
        end
      end

      context 'when all conditions are met' do
        before do
          allow(group).to receive(:code_suggestions_purchased?).and_return(true)
        end

        it 'renders the option' do
          render

          expect(rendered).to render_template('groups/settings/_auto_assign_duo_pro')
          expect(rendered).to have_content('Automatic assignment of GitLab Duo Pro seats')
        end
      end
    end
  end

  context 'for experimental settings' do
    context 'when settings are disabled' do
      it 'renders nothing' do
        allow(group).to receive(:experiment_settings_allowed?).and_return(false)

        render

        expect(rendered).to render_template('groups/settings/_experimental_settings')
        expect(rendered).not_to have_content('GitLab Duo experiment and beta features')
      end
    end

    context 'when experiment settings for group is enabled' do
      it 'renders the experiment settings' do
        allow(group).to receive(:experiment_settings_allowed?).and_return(true)

        render

        expect(rendered).to render_template('groups/settings/_experimental_settings')
        expect(rendered).to have_content('GitLab Duo experiment and beta features')
      end
    end
  end
end
