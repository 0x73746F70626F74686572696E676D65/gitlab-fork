# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab_subscriptions/trials/duo_pro/_advantages_list.html.haml', feature_category: :subscription_management do
  it 'renders the list' do
    render 'gitlab_subscriptions/trials/duo_pro/advantages_list'

    expect(rendered).to have_content(s_("DuoProTrial|GitLab Duo Pro is designed to make teams more efficient " \
                                        "throughout the software development lifecycle with:"))
    expect(rendered).to have_content(s_('DuoProTrial|Code completion and code generation with Code Suggestions'))
    expect(rendered).to have_content(s_('DuoProTrial|Organizational controls'))
    expect(rendered).to have_content(s_('DuoProTrial|Chat'))
    expect(rendered).to have_content(s_('DuoProTrial|Code explanation'))
    expect(rendered).to have_content(s_('DuoProTrial|Code refactorization'))
    expect(rendered).to have_content(s_('DuoProTrial|Test generation'))
    expect(rendered).to have_content(s_("DuoProTrial|GitLab Duo Pro is only available for purchase for Premium and " \
                                        "Ultimate users."))
  end
end
