# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Zoekt search', :zoekt, :js, :disable_rate_limiter, :elastic, :zoekt_settings_enabled, feature_category: :global_search do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project1) { create(:project, :repository, :public, namespace: group) }
  let_it_be(:project2) { create(:project, :repository, :public, namespace: group) }
  let_it_be(:private_group) { create(:group, :private) }
  let_it_be(:private_project) { create(:project, :repository, :private, namespace: private_group) }

  def choose_group(group)
    find_by_testid('group-filter').click
    wait_for_requests

    within_testid('group-filter') do
      select_listbox_item group.name
    end
  end

  def choose_project(project)
    find_by_testid('project-filter').click
    wait_for_requests

    within_testid('project-filter') do
      select_listbox_item project.name
    end
  end

  before do
    # Necessary as group scoped code search is
    # not available without Elasticsearch enabled
    # even though it's using Zoekt.
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    stub_feature_flags(zoekt_cross_namespace_search: false)

    zoekt_ensure_project_indexed!(project1)
    zoekt_ensure_project_indexed!(project2)
    zoekt_ensure_project_indexed!(private_project)

    project1.add_maintainer(user)
    project2.add_maintainer(user)
    group.add_owner(user)

    sign_in(user)

    visit(search_path)

    wait_for_requests

    choose_group(group)
  end

  it 'finds files with a regex search and allows filtering down again by project' do
    submit_search('user.*egex')
    select_search_scope('Code')

    expect(page).to have_selector('.file-content .blob-content', count: 2)
    expect(page).to have_button('Copy file path')

    choose_project(project1)

    expect(page).to have_selector('.file-content .blob-content', count: 1)

    allow(Ability).to receive(:allowed?).and_call_original
    expect(Ability).to receive(:allowed?).with(anything, :read_blob, anything).twice.and_return(false)

    submit_search("username_regex")
    select_search_scope('Code')

    expect(page).not_to have_selector('.file-content .blob-content')
  end

  it 'displays that exact code search is enabled' do
    submit_search('test')
    select_search_scope('Code')
    expect(page).to have_link('Exact code search (powered by Zoekt)',
      href: help_page_path('user/search/exact_code_search'))
  end
end
