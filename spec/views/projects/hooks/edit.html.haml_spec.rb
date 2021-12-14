# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/hooks/edit' do
  let(:hook) { create(:project_hook, project: project) }

  let_it_be_with_refind(:project) { create(:project) }

  before do
    assign :project, project
    assign :hook, hook
  end

  it 'renders webhook page with "Recent events"' do
    render

    expect(rendered).to have_css('h4', text: 'Webhook')
    expect(rendered).to have_text('Recent events')
  end

  context 'webhook is rate limited' do
    before do
      allow(hook).to receive(:rate_limited?).and_return(true)
    end

    it 'renders alert' do
      render

      expect(rendered).to have_text('Webhook was automatically disabled')
    end
  end
end
