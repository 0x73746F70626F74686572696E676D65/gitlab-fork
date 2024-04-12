# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/_permissions.html.haml', :saas, feature_category: :code_suggestions do
  let_it_be(:group) { build(:group, namespace_settings: build(:namespace_settings)) }

  before do
    assign(:group, group)
    allow(view).to receive(:can?).and_return(true)
    allow(view).to receive(:current_user).and_return(build(:user))
  end

  context 'for code suggestions' do
    before do
      stub_feature_flags(purchase_code_suggestions: false)
    end

    context 'when add on not purchased' do
      it 'renders alert to contact sales' do
        allow(group).to receive(:code_suggestions_purchased?).and_return(false)

        render

        expect(rendered).to render_template('groups/settings/_code_suggestions')
        expect(rendered).to have_content(
          'Code Suggestions free access has ended ' \
          'Purchase the Duo Pro add-on to use Code Suggestions.'
        )
      end
    end

    context 'when add on purchased ' do
      it 'renders alert with link to settings' do
        allow(group).to receive(:code_suggestions_purchased?).and_return(true)

        render

        expect(rendered).to render_template('groups/settings/_code_suggestions')
        expect(rendered).to have_content('Manage user access for Code Suggestions on the usage quotas page.')
      end
    end
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
        expect(rendered).not_to have_content('Duo features')
      end
    end

    context 'when licensed ai features are available' do
      it 'renders the experiment settings' do
        allow(group).to receive(:licensed_ai_features_available?).and_return(true)

        render

        expect(rendered).to render_template('groups/settings/_duo_features_enabled')
        expect(rendered).to have_content('Duo features')
      end
    end
  end

  context 'for experimental settings' do
    context 'when settings are disabled' do
      it 'renders nothing' do
        allow(group).to receive(:experiment_settings_allowed?).and_return(false)

        render

        expect(rendered).to render_template('groups/settings/_experimental_settings')
        expect(rendered).not_to have_content('Experiment and Beta features')
      end
    end

    context 'when experiment settings for group is enabled' do
      it 'renders the experiment settings' do
        allow(group).to receive(:experiment_settings_allowed?).and_return(true)

        render

        expect(rendered).to render_template('groups/settings/_experimental_settings')
        expect(rendered).to have_content('Experiment and Beta features')
      end
    end
  end
end
