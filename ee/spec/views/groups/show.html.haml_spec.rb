# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/show', feature_category: :groups_and_projects do
  let(:group) { build(:group) }

  before do
    assign(:group, group)
  end

  it 'renders the Duo Chat GA alert partial' do
    render

    expect(rendered).to render_template('shared/_duo_chat_ga_alert')
  end
end
