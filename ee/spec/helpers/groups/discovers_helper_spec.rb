# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::DiscoversHelper, feature_category: :activation do
  describe '#discover_details' do
    subject(:discover_details) { helper.trial_discover_page_details }

    it 'returns an array' do
      expect(discover_details).to be_a(Array)
    end

    it 'contains correct number of items' do
      expect(discover_details.count).to be(3)
    end

    it 'returns correct features' do
      expect(discover_details[0][:title]).to eq(s_("TrialDiscoverPage|Collaboration made easy"))
      expect(discover_details[1][:title]).to eq(s_("TrialDiscoverPage|Lower cost of development"))
      expect(discover_details[2][:title]).to eq(s_("TrialDiscoverPage|Your software, deployed your way"))
    end
  end

  describe '#discover_features' do
    subject(:discover_features) { helper.trial_discover_page_features }

    it 'returns an array' do
      expect(discover_features).to be_a(Array)
    end

    it 'contains correct number of items' do
      expect(discover_features.count).to be(10)
    end

    it 'returns correct features' do
      expect(discover_features[0][:title]).to eq(s_("TrialDiscoverPage|Epics"))
      expect(discover_features[1][:title]).to eq(s_("TrialDiscoverPage|Roadmaps"))
      expect(discover_features[2][:title]).to eq(s_("TrialDiscoverPage|Scoped Labels"))
      expect(discover_features[3][:title]).to eq(s_("TrialDiscoverPage|Merge request approval rule"))
      expect(discover_features[4][:title]).to eq(s_("TrialDiscoverPage|Burn down charts"))
      expect(discover_features[5][:title]).to eq(s_("TrialDiscoverPage|Code owners"))
      expect(discover_features[6][:title]).to eq(s_("TrialDiscoverPage|Code review analytics"))
      expect(discover_features[7][:title]).to eq(s_("TrialDiscoverPage|Free guest users"))
      expect(discover_features[8][:title]).to eq(s_("TrialDiscoverPage|Dependency scanning"))
      expect(discover_features[9][:title]).to eq(s_("TrialDiscoverPage|Dynamic application security testing (DAST)"))
    end

    it 'returns correct tracking labels' do
      expect(discover_features[0][:tracking_label]).to eq("epics_feature")
      expect(discover_features[1][:tracking_label]).to eq("roadmaps_feature")
      expect(discover_features[2][:tracking_label]).to eq("scoped_labels_feature")
      expect(discover_features[3][:tracking_label]).to eq("merge_request_rule_feature")
      expect(discover_features[4][:tracking_label]).to eq("burn_down_chart_feature")
      expect(discover_features[5][:tracking_label]).to eq("code_owners_feature")
      expect(discover_features[6][:tracking_label]).to eq("code_review_feature")
      expect(discover_features[7][:tracking_label]).to eq("free_guests_feature")
      expect(discover_features[8][:tracking_label]).to eq("dependency_scanning_feature")
      expect(discover_features[9][:tracking_label]).to eq("dast_feature")
    end
  end

  describe '#group_trial_status' do
    let_it_be(:group) { build_stubbed(:group) }

    context 'when trial is active' do
      before do
        allow(group).to receive(:trial_active?).and_return(true)
      end

      it 'returns correct status' do
        expect(helper.group_trial_status(group)).to eq 'trial_active'
      end
    end

    context 'when trial is expired' do
      before do
        allow(group).to receive(:trial_active?).and_return(false)
      end

      it 'returns correct status' do
        expect(helper.group_trial_status(group)).to eq 'trial_expired'
      end
    end
  end
end
