# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions/trials/duo_pro/_lead_form.html.haml', feature_category: :subscription_management do
  let(:user) { build_stubbed(:user) }

  before do
    allow(view).to receive(:current_user) { user }
  end

  it 'renders lead form' do
    render 'gitlab_subscriptions/trials/duo_pro/lead_form'

    expect(rendered).to have_content(s_('DuoProTrial|Start your free GitLab Duo Pro trial'))
    expect(rendered).to have_content(s_('DuoProTrial|We just need some additional information to activate your trial.'))
    expect(rendered).to render_template('gitlab_subscriptions/trials/duo_pro/_advantages_list')
  end
end
