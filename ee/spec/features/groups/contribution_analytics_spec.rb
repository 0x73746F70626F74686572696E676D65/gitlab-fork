# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Contribution Analytics', :js, feature_category: :value_stream_management do
  let(:user) { create(:user) }
  let(:group) { create(:group) }
  let(:empty_project) { create(:project, namespace: group) }

  def visit_contribution_analytics
    visit group_path(group)

    within_testid('super-sidebar') do
      click_button 'Analyze'
      click_link 'Contribution analytics'
    end
  end

  before do
    group.add_owner(user)
    sign_in(user)
  end

  describe 'visit Contribution Analytics page for group' do
    before do
      visit_contribution_analytics
    end

    it 'displays Contribution Analytics' do
      expect(page).to have_content "Contribution analytics for issues, merge requests and push"
    end

    it 'displays text indicating no pushes, merge requests and issues' do
      expect(page).to have_content "No pushes for the selected time period."
      expect(page).to have_content "No merge requests for the selected time period."
      expect(page).to have_content "No issues for the selected time period."
    end
  end

  describe 'Contribution Analytics Tabs' do
    before do
      visit group_contribution_analytics_path(group)
    end

    it 'displays the Date Range GlTabs' do
      within_testid('contribution-analytics-date-nav') do
        expect(page).to have_link 'Last week',
          href: group_contribution_analytics_path(group, start_date: 1.week.ago.to_date)
        expect(page).to have_link 'Last month',
          href: group_contribution_analytics_path(group, start_date: 1.month.ago.to_date)
        expect(page).to have_link 'Last 3 months',
          href: group_contribution_analytics_path(group, start_date: 3.months.ago.to_date)
      end
    end

    it 'defaults active to Last Week' do
      within_testid('contribution-analytics-date-nav') do
        expect(page.find('.active')).to have_text('Last week')
      end
    end

    it 'clicking a different option updates correctly' do
      within_testid('contribution-analytics-date-nav') do
        page.find_link('Last 3 months').click
      end

      wait_for_requests

      within_testid('contribution-analytics-date-nav') do
        expect(page.find('.active')).to have_text('Last 3 months')
      end
    end
  end

  describe('Contribution Analytics data source') do
    let(:using_clickhouse_badge) { find_by_testid('using-clickhouse-badge') }

    context 'when ClickHouse is the data source' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
        visit_contribution_analytics
      end

      it 'displays `Using ClickHouse` badge' do
        within_testid('contribution-analytics-header') do
          expect(using_clickhouse_badge).to have_text('Using ClickHouse')
        end
      end

      it 'displays popover upon hovering over `Using ClickHouse` badge',
        quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/446043' do
        using_clickhouse_badge.hover

        page.within('.gl-popover') do
          expect(page).to have_content(
            'This page sources data from the analytical database ClickHouse, ' \
            'with a few minutes of delay.'
          )
        end
      end
    end

    context 'when ClickHouse is not the data source' do
      before do
        allow(::Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)
        visit_contribution_analytics
      end

      it 'does not display `Using ClickHouse` badge' do
        within_testid('contribution-analytics-header') do
          expect(page).not_to have_content('Using ClickHouse')
        end
      end
    end
  end
end
