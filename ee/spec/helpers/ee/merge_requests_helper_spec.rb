# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::MergeRequestsHelper, feature_category: :code_review_workflow do
  include Users::CalloutsHelper
  include ApplicationHelper
  include PageLayoutHelper
  include ProjectsHelper

  describe '#render_items_list' do
    it "returns one item in the list" do
      expect(render_items_list(["user"])).to eq("user")
    end

    it "returns two items in the list" do
      expect(render_items_list(%w[user user1])).to eq("user and user1")
    end

    it "returns three items in the list" do
      expect(render_items_list(%w[user user1 user2])).to eq("user, user1 and user2")
    end
  end

  describe '#diffs_tab_pane_data' do
    subject(:diffs_tab_pane_data) { helper.diffs_tab_pane_data(project, merge_request, {}) }

    let_it_be(:current_user) { build_stubbed(:user) }
    let_it_be(:project) { build_stubbed(:project) }
    let_it_be(:merge_request) { build_stubbed(:merge_request, project: project) }

    before do
      project.add_developer(current_user)

      allow(helper).to receive(:current_user).and_return(current_user)
    end

    context 'for endpoint_codequality' do
      before do
        stub_licensed_features(inline_codequality: true)

        allow(merge_request).to receive(:has_codequality_mr_diff_report?).and_return(true)
      end

      it 'returns expected value' do
        expect(
          subject[:endpoint_codequality]
        ).to eq("/#{project.full_path}/-/merge_requests/#{merge_request.iid}/codequality_mr_diff_reports.json")
      end
    end

    context 'for codequality_report_available' do
      context 'when feature is licensed' do
        before do
          stub_licensed_features(inline_codequality: true)

          allow(merge_request).to receive(:has_codequality_reports?).and_return('true')
        end

        it 'returns expected value' do
          expect(subject[:codequality_report_available]).to eq('true')
        end

        context 'when merge request does not have codequality reports' do
          before do
            allow(merge_request).to receive(:has_codequality_reports?).and_return('false')
          end

          it 'returns expected value' do
            expect(subject[:codequality_report_available]).to eq('false')
          end
        end
      end

      context 'when feature is not licensed' do
        it 'does not return the variable' do
          expect(subject).not_to have_key(:codequality_report_available)
        end
      end
    end

    context 'for sast_report_available' do
      before do
        allow(merge_request).to receive(:has_sast_reports?).and_return(true)
      end

      it 'returns expected value' do
        expect(subject[:sast_report_available]).to eq('true')
      end

      context 'when merge request does not have SAST reports' do
        before do
          allow(merge_request).to receive(:has_sast_reports?).and_return(false)
        end

        it 'returns expected value' do
          expect(subject[:sast_report_available]).to eq('false')
        end
      end
    end
  end

  describe '#review_llm_summary_allowed?' do
    let(:user) { build_stubbed(:user) }
    let(:merge_request) { build_stubbed(:merge_request) }

    it 'calls Ability.allowed? with summarize_submitted_review' do
      expect(Ability)
        .to receive(:allowed?)
        .with(user, :summarize_submitted_review, merge_request)
        .and_return(true)

      expect(review_llm_summary_allowed?(merge_request, user)).to eq(true)
    end
  end

  describe '#review_llm_summary' do
    let_it_be(:merge_request) { build_stubbed(:merge_request) }
    let_it_be(:reviewer) { build_stubbed(:user) }
    let(:latest_merge_request_diff) { instance_double(MergeRequestDiff) }

    before do
      allow(merge_request)
        .to receive(:latest_merge_request_diff)
        .and_return(latest_merge_request_diff)
    end

    it 'returns latest review summary from reviewer' do
      latest_review_summary = instance_double(MergeRequest::ReviewLlmSummary)

      expect(latest_merge_request_diff)
        .to receive(:latest_review_summary_from_reviewer)
        .with(reviewer)
        .and_return(latest_review_summary)

      expect(review_llm_summary(merge_request, reviewer)).to eq(latest_review_summary)
    end

    context 'when merge request has no latest merge request diff' do
      let(:latest_merge_request_diff) { nil }

      it 'returns nil' do
        expect(review_llm_summary(merge_request, reviewer)).to be_nil
      end
    end
  end

  describe '#mr_compare_form_data' do
    let_it_be(:project) { build_stubbed(:project) }
    let_it_be(:merge_request) { build_stubbed(:merge_request, source_project: project) }
    let_it_be(:user) { build_stubbed(:user) }

    subject(:mr_compare_form_data) { helper.mr_compare_form_data(user, merge_request) }

    describe 'when the project does not have the correct license' do
      before do
        stub_licensed_features(target_branch_rules: false)
      end

      it 'returns target_branch_finder_path as nil' do
        expect(subject[:target_branch_finder_path]).to eq(nil)
      end
    end

    describe 'when the project has the correct license' do
      before do
        stub_licensed_features(target_branch_rules: true)
      end

      it 'returns target_branch_finder_path' do
        expect(subject[:target_branch_finder_path]).to eq(project_target_branch_rules_path(project))
      end
    end
  end

  describe '#show_video_component?' do
    before do
      allow(helper).to receive(:current_user).and_return(nil)
    end

    context 'when project is nil' do
      subject do
        helper.show_video_component?(nil)
      end

      it 'returns false' do
        expect(subject).to eq(false)
      end
    end

    context 'when project is set' do
      let_it_be(:project) { build_stubbed(:project) }

      subject do
        helper.show_video_component?(project)
      end

      context 'when user is not signed in' do
        it 'returns false' do
          expect(subject).to eq(false)
        end
      end

      context 'when user is signed in' do
        before do
          allow(helper).to receive(:current_user).and_return(
            build_stubbed(:user, created_at: IssuesMrsEmptyStateExperiment::EXCLUDE_USERS_OLDER_THAN)
          )
        end

        describe 'when control behavior' do
          before do
            stub_experiments(issues_mrs_empty_state: :control)
          end

          it 'returns false' do
            expect(subject).to eq(false)
          end
        end

        describe 'when candidate behavior' do
          before do
            stub_experiments(issues_mrs_empty_state: :candidate)
          end

          it 'returns true' do
            expect(subject).to eq(true)
          end
        end
      end
    end
  end
end
