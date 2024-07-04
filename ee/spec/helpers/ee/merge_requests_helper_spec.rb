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

  describe '#identity_verification_alert_data' do
    let_it_be(:current_user) { build_stubbed(:user) }
    let(:author) { current_user }
    let(:merge_request) { build_stubbed(:merge_request, author: author) }

    subject { helper.identity_verification_alert_data(merge_request) }

    before do
      allow(helper).to receive(:current_user).and_return(current_user)
      allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
        allow(instance).to receive(:user_can_run_jobs?).and_return(false)
      end
    end

    shared_examples 'returns the correct data' do
      specify do
        expected_data = {
          identity_verification_required: iv_required.to_s,
          identity_verification_path: identity_verification_path
        }

        expect(subject).to eq(expected_data)
      end
    end

    it_behaves_like 'returns the correct data' do
      let(:iv_required) { true }
    end

    context 'when the MR author is not the current user' do
      let(:author) { build_stubbed(:user) }

      it_behaves_like 'returns the correct data' do
        let(:iv_required) { false }
      end
    end

    context 'when the user is authorized to run jobs' do
      before do
        allow_next_instance_of(::Users::IdentityVerification::AuthorizeCi) do |instance|
          allow(instance).to receive(:user_can_run_jobs?).and_return(true)
        end
      end

      it_behaves_like 'returns the correct data' do
        let(:iv_required) { false }
      end
    end
  end
end
