# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/show', feature_category: :groups_and_projects do
  let(:project) { ProjectPresenter.new(create(:project), current_user: build(:user)) } # rubocop:todo RSpec/FactoryBot/AvoidCreate -- sidebar rendering need to access project statistics

  before do
    assign(:project, project)
    allow(project).to receive(:default_view).and_return('wiki')
  end

  it 'renders the Duo Chat GA alert partial' do
    render

    expect(rendered).to render_template('projects/_duo_chat_ga_alert')
  end
end
