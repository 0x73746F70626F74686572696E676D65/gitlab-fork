# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/discovers/show', :saas, :aggregate_failures, feature_category: :activation do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:group) { build_stubbed(:group) }
  let(:tracking_labels) do
    [
      :epics_feature,
      :roadmaps_feature,
      :scoped_labels_feature,
      :merge_request_rule_feature,
      :burn_down_chart_feature,
      :code_owners_feature,
      :code_review_feature,
      :dependency_scanning_feature,
      :dast_feature
    ]
  end

  before do
    allow(view).to receive(:current_user).and_return(user)
    assign(:group, group)
  end

  it 'renders the discover trial page' do
    render

    expect(rendered).to have_text(s_('TrialDiscoverPage|Discover Premium & Ultimate'))
    expect(rendered).to have_text(s_('TrialDiscoverPage|Access advanced features'))
    expect(rendered).to render_template('groups/discovers/_discover_page_actions')
  end

  it 'renders all feature cards' do
    render

    expect(rendered).to have_text(s_("TrialDiscoverPage|Epics"))
    expect(rendered).to have_text(s_("TrialDiscoverPage|Roadmaps"))
    expect(rendered).to have_text(s_("TrialDiscoverPage|Scoped Labels"))
    expect(rendered).to have_text(s_("TrialDiscoverPage|Merge request approval rule"))
    expect(rendered).to have_text(s_("TrialDiscoverPage|Burn down charts"))
    expect(rendered).to have_text(s_("TrialDiscoverPage|Code owners"))
    expect(rendered).to have_text(s_("TrialDiscoverPage|Code review analytics"))
    expect(rendered).to have_text(s_("TrialDiscoverPage|Free guest users"))
    expect(rendered).to have_text(s_("TrialDiscoverPage|Dependency scanning"))
    expect(rendered).to have_text(s_("TrialDiscoverPage|Dynamic application security testing (DAST)"))
    expect(rendered).to have_text(s_("TrialDiscoverPage|Collaboration made easy"))
    expect(rendered).to have_text(s_("TrialDiscoverPage|Lower cost of development"))
    expect(rendered).to have_text(s_("TrialDiscoverPage|Your software, deployed your way"))
  end

  context 'when trial is active' do
    before do
      allow(group).to receive(:trial_active?).and_return(true)
    end

    it 'has tracking items set as expected' do
      render

      tracking_labels.each do |label|
        expect_to_have_experiment_tracking(action: 'click_video_link_trial_active', label: label)
        expect_to_have_experiment_tracking(action: 'click_documentation_link_trial_active', label: label)
      end
    end

    it 'has tracking for Free guest users' do
      render

      expect_to_have_experiment_tracking(action: 'click_calculate_seats_trial_active', label: :free_guests_feature)
      expect_to_have_experiment_tracking(action: 'click_documentation_link_trial_active', label: :free_guests_feature)
    end

    it 'has tracking for page actions' do
      render

      expect_to_have_experiment_tracking(action: 'click_compare_plans', label: :trial_active)
      expect_to_have_hand_raise_lead_tracking
    end
  end

  context 'when trial is expired' do
    before do
      allow(group).to receive(:trial_active?).and_return(false)
    end

    it 'has tracking items set as expected' do
      render

      tracking_labels.each do |label|
        expect_to_have_experiment_tracking(action: 'click_video_link_trial_expired', label: label)
        expect_to_have_experiment_tracking(action: 'click_documentation_link_trial_expired', label: label)
      end
    end

    it 'has tracking for Free guest users' do
      render

      expect_to_have_experiment_tracking(action: 'click_calculate_seats_trial_expired', label: :free_guests_feature)
      expect_to_have_experiment_tracking(action: 'click_documentation_link_trial_expired', label: :free_guests_feature)
    end

    it 'has tracking for page actions' do
      render

      expect_to_have_experiment_tracking(action: 'click_compare_plans', label: :trial_expired)
      expect_to_have_hand_raise_lead_tracking(label: :trial_expired)
    end
  end

  def expect_to_have_experiment_tracking(action:, label: nil)
    css = "[data-track-action='#{action}']"
    css += "[data-track-experiment='trial_discover_page']"
    css += "[data-track-label='#{label}']" if label

    expect(rendered).to have_css(css)
  end

  def expect_to_have_hand_raise_lead_tracking(label: :trial_active)
    tracking = {
      track_action: 'click_contact_sales',
      track_label: label,
      track_experiment: :trial_discover_page
    }.to_json

    expect(rendered).to have_css("[data-cta-tracking='#{tracking}']")
  end
end
