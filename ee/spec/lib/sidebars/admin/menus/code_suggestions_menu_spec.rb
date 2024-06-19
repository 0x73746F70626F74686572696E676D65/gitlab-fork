# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::CodeSuggestionsMenu, feature_category: :navigation do
  it_behaves_like 'Admin menu',
    link: '/admin/code_suggestions',
    title: s_('Admin|GitLab Duo'),
    icon: 'tanuki-ai'

  it_behaves_like 'Admin menu without sub menus', active_routes: { controller: :code_suggestions }
end
