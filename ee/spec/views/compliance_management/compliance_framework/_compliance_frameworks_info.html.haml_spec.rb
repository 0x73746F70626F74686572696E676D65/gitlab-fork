# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'compliance_management/compliance_framework/_compliance_framework_info.html.haml' do
  let(:group) { build_stubbed(:group) }
  let(:framework1) { build_stubbed(:compliance_framework) }
  let(:project) do
    build_stubbed(:project, namespace: group,
      compliance_framework_settings:
      [build_stubbed(:compliance_framework_project_setting, compliance_management_framework: framework1)])
  end

  before do
    allow(view).to receive(:show_compliance_frameworks_info?).and_return(true)
    allow(view).to receive(:can?).with(anything, :maintainer_access, project.root_ancestor).and_return(false)
  end

  it 'renders compliance framework badges' do
    render('compliance_management/compliance_framework/compliance_frameworks_info', project: project)
    expect(rendered).to have_selector('[data-testid="compliance-frameworks-info"]', count: 1)
    expect(rendered).to have_content(framework1.name)
  end

  context 'when user is not a group maintainer' do
    it 'renders tooltip for badges' do
      render('compliance_management/compliance_framework/compliance_frameworks_info', project: project)
      expect(rendered).to have_css('.has-tooltip')
    end
  end

  context 'when user is a group maintainer' do
    before do
      allow(view).to receive(:show_compliance_frameworks_info?).and_return(true)
      allow(view).to receive(:can?).with(anything, :maintainer_access, project.root_ancestor).and_return(true)
    end

    it 'does not render tooltip for badges' do
      render('compliance_management/compliance_framework/compliance_frameworks_info', project: project)
      expect(rendered).not_to have_selector('.has-tooltip')
    end

    it 'renders the link to compliance path' do
      render('compliance_management/compliance_framework/compliance_frameworks_info', project: project)
      expect(rendered).to have_link(nil, href: compliance_center_path(project))
    end
  end

  context 'when show_compliance_frameworks_info? is false' do
    before do
      allow(view).to receive(:show_compliance_frameworks_info?).and_return(false)
    end

    it 'does not render any badge' do
      render('compliance_management/compliance_framework/compliance_frameworks_info', project: project)

      expect(rendered).not_to have_css('.project-page-sidebar-block')
    end
  end
end
