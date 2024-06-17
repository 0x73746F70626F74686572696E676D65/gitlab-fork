# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions/trials/duo_pro/_select_namespace_form.html.haml', feature_category: :subscription_management do
  let(:user) { build_stubbed(:user) }
  let(:group) { build_stubbed(:group) }

  before do
    allow(view).to receive(:current_user) { user }
    assign(:eligible_namespaces, [group])
  end

  it 'renders select namespace form' do
    render 'gitlab_subscriptions/trials/duo_pro/select_namespace_form'

    expect(rendered).to have_content(s_('DuoProTrial|Apply your GitLab Duo Pro trial to an existing group'))
    expect(rendered).to have_content(_('Who will be using GitLab?'))
    expect(rendered).to have_content(_('My company or team'))
    expect(rendered).to have_content(_('Just me'))

    expect(rendered).to render_template('gitlab_subscriptions/trials/duo_pro/_advantages_list')
  end
end
