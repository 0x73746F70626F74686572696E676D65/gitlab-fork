# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '"Your work" navbar', feature_category: :navigation do
  include_context 'dashboard navbar structure'

  let_it_be(:user) { create(:user, :no_super_sidebar) }

  it_behaves_like 'verified navigation bar' do
    before do
      sign_in(user)
      visit root_path
    end
  end
end
