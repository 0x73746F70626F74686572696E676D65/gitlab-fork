# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/ai/terms_and_conditions/index.html.haml', feature_category: :custom_models do
  subject { render && rendered }

  it do
    is_expected.to have_link('Learn more.', href: '/help/administration/self_hosted_models/install_infrastructure')
  end

  it { is_expected.to have_link('Enable self-hosted models', href: admin_ai_terms_and_conditions_url) }
  it { is_expected.to have_link('GitLab Testing Agreement', href: 'https://about.gitlab.com/handbook/legal/testing-agreement/') }
end
