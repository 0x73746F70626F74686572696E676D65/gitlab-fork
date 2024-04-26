# frozen_string_literal: true

require 'spec_helper'

# Store feature-specific specs in `ee/spec/models/merge_request instead of
# making this file longer.
#
# For instance, `ee/spec/models/merge_request/blocking_spec.rb` tests the
# "blocking MRs" feature.
RSpec.describe MergeRequest, feature_category: :code_review_workflow do
  using RSpec::Parameterized::TableSyntax
  include ReactiveCachingHelpers

  let_it_be_with_reload(:project) { create(:project, :repository) }

  let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  describe 'associations' do
    subject { build_stubbed(:merge_request) }

    it { is_expected.to belong_to(:iteration) }
    it { is_expected.to have_many(:approvals).dependent(:delete_all) }
    it { is_expected.to have_many(:approvers).dependent(:delete_all) }
    it { is_expected.to have_many(:approver_users).through(:approvers) }
    it { is_expected.to have_many(:approver_groups).dependent(:delete_all) }
    it { is_expected.to have_many(:approved_by_users) }
    it { is_expected.to have_one(:merge_train_car) }
    it { is_expected.to have_many(:approval_rules) }
    it { is_expected.to have_many(:approval_merge_request_rule_sources).through(:approval_rules) }
    it { is_expected.to have_many(:approval_project_rules).through(:approval_merge_request_rule_sources) }
    it { is_expected.to have_many(:status_check_responses).class_name('MergeRequests::StatusCheckResponse').inverse_of(:merge_request) }
    it { is_expected.to have_many(:compliance_violations).class_name('MergeRequests::ComplianceViolation') }

    describe 'approval_rules association' do
      describe 'applicable_post_merge_approval_rules' do
        it 'returns only the rules applicable_post_merge true or nil' do
          create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: false)
          rule_2 = create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: true)
          rule_3 = create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: true)

          expect(merge_request.applicable_post_merge_approval_rules).to contain_exactly(rule_2, rule_3)
        end
      end

      describe '#applicable_to_branch' do
        let!(:rule) { create(:approval_merge_request_rule, merge_request: merge_request) }
        let(:branch) { 'stable' }

        subject { merge_request.approval_rules.applicable_to_branch(branch) }

        shared_examples_for 'with applicable rules to specified branch' do
          it { is_expected.to eq([rule]) }
        end

        context 'when there are no associated source rules' do
          it_behaves_like 'with applicable rules to specified branch'
        end

        context 'when there are associated source rules' do
          let!(:source_rule) { create(:approval_project_rule, project: merge_request.target_project) }
          let!(:rule) { create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: source_rule) }

          context 'and rule is not modified_from_project_rule' do
            before do
              rule.update!(
                name: source_rule.name,
                approvals_required: source_rule.approvals_required,
                users: source_rule.users,
                groups: source_rule.groups
              )
            end

            context 'and there are no associated protected branches to source rule' do
              it_behaves_like 'with applicable rules to specified branch'
            end

            context 'and there are associated protected branches to source rule' do
              before do
                source_rule.update!(protected_branches: protected_branches)
              end

              context 'and branch matches' do
                let(:protected_branches) { [create(:protected_branch, name: branch)] }

                it_behaves_like 'with applicable rules to specified branch'
              end

              context 'and branch does not match anything' do
                let(:protected_branches) { [create(:protected_branch, name: branch.reverse)] }

                it { is_expected.to be_empty }
              end
            end
          end

          context 'and rule is modified_from_project_rule' do
            before do
              rule.update!(name: 'Overridden Rule')
            end

            it_behaves_like 'with applicable rules to specified branch'
          end

          context 'and rule is overridden but not modified_from_project_rule' do
            let!(:rule) { create(:approval_merge_request_rule, name: 'test', merge_request: merge_request, approval_project_rule: source_rule) }

            it_behaves_like 'with applicable rules to specified branch'

            context 'and protected branches exist but branch does not match anything' do
              let(:protected_branches) { [create(:protected_branch, name: branch.reverse)] }

              before do
                source_rule.update!(protected_branches: protected_branches)
              end

              it 'does not find applicable rules' do
                expect(subject).to be_empty
              end
            end
          end
        end
      end

      describe '#set_applicable_when_copying_rules' do
        let!(:rule_2) { create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: nil) }
        let!(:rule_1) { create(:approval_merge_request_rule, merge_request: merge_request, applicable_post_merge: nil) }
        let(:ids) { [rule_2.id] }

        subject { merge_request.approval_rules.set_applicable_when_copying_rules(ids) }

        it 'sets all the ids to true and others to false' do
          pre_set = merge_request.approval_rules.all? { |rule| rule.applicable_post_merge.nil? }
          expect(pre_set).to eq(true)

          subject

          expect(rule_1.reload.applicable_post_merge).to eq(false)
          expect(rule_2.reload.applicable_post_merge).to eq(true)
        end
      end
    end

    describe '#merge_requests_author_approval?' do
      context 'when project lacks a target_project relation' do
        before do
          merge_request.target_project = nil
        end

        it 'returns false' do
          expect(merge_request.merge_requests_author_approval?).to be false
        end
      end

      context 'when project has a target_project relation' do
        it 'accesses the value from the target_project' do
          expect(merge_request.target_project)
            .to receive(:merge_requests_author_approval?)

          merge_request.merge_requests_author_approval?
        end

        context 'when overriden by scan result policy' do
          let(:policy) do
            create(
              :scan_result_policy_read,
              :prevent_approval_by_author,
              commits: :any,
              project: merge_request.target_project)
          end

          before do
            merge_request.target_project.update_attribute(:merge_requests_author_approval, true)

            create(
              :approval_merge_request_rule,
              :any_merge_request,
              merge_request: merge_request,
              scan_result_policy_read: policy)
            create(
              :scan_result_policy_violation,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: policy)
          end

          it 'returns false' do
            expect(merge_request.merge_requests_author_approval?).to be(false)
          end
        end
      end
    end

    describe '#merge_requests_disable_committers_approval?' do
      context 'when project lacks a target_project relation' do
        before do
          merge_request.target_project = nil
        end

        it 'returns false' do
          expect(merge_request.merge_requests_disable_committers_approval?).to be false
        end
      end

      context 'when project has a target_project relation' do
        it 'accesses the value from the target_project' do
          expect(merge_request.target_project)
            .to receive(:merge_requests_disable_committers_approval?)

          merge_request.merge_requests_disable_committers_approval?
        end

        context 'when overriden by scan result policy' do
          let(:policy) do
            create(
              :scan_result_policy_read,
              :prevent_approval_by_commit_author,
              commits: :any,
              project: merge_request.target_project)
          end

          before do
            merge_request.target_project.update_attribute(:merge_requests_disable_committers_approval, false)

            create(
              :approval_merge_request_rule,
              :any_merge_request,
              merge_request: merge_request,
              scan_result_policy_read: policy)
            create(
              :scan_result_policy_violation,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: policy)
          end

          it 'returns false' do
            expect(merge_request.merge_requests_disable_committers_approval?).to be(true)
          end
        end
      end
    end

    describe '#require_password_to_approve?' do
      subject { merge_request.require_password_to_approve? }

      let(:password_required?) { true }

      before do
        merge_request.target_project.update!(require_password_to_approve: password_required?)
      end

      context 'when target project requires password' do
        it { is_expected.to be(password_required?) }
      end

      context 'when target project does not require password' do
        let(:password_required?) { false }

        it { is_expected.to be(password_required?) }

        context 'when overridden by scan result policy' do
          let(:policy) do
            create(
              :scan_result_policy_read,
              :require_password_to_approve,
              commits: :any,
              project: merge_request.target_project)
          end

          before do
            merge_request.target_project.update_attribute(:merge_requests_disable_committers_approval, false)

            create(
              :approval_merge_request_rule,
              :any_merge_request,
              merge_request: merge_request,
              scan_result_policy_read: policy)
            create(
              :scan_result_policy_violation,
              project: project,
              merge_request: merge_request,
              scan_result_policy_read: policy)
          end

          it { is_expected.to be(true) }
        end
      end

      describe '#policy_approval_settings' do
        let(:project_approval_settings) do
          { prevent_approval_by_author: true,
            prevent_approval_by_commit_author: false,
            remove_approvals_with_new_commit: true,
            require_password_to_approve: false }
        end

        let(:policy) do
          create(:scan_result_policy_read,
            project: merge_request.target_project,
            project_approval_settings: project_approval_settings)
        end

        let(:overrides) { project_approval_settings.select { |_, v| v } }

        subject(:approval_settings) { merge_request.policy_approval_settings }

        context 'with scan finding rule' do
          let!(:approval_merge_request_rule) do
            create(:report_approver_rule,
              :scan_finding,
              merge_request: merge_request,
              scan_result_policy_read: policy)
          end

          context 'when violated' do
            before do
              create(:scan_result_policy_violation, project: project, merge_request: merge_request,
                scan_result_policy_read: approval_merge_request_rule.scan_result_policy_read)
            end

            it { is_expected.to eq(overrides) }

            context 'when scan_result_policy_violations is already loaded' do
              before do
                merge_request.scan_result_policy_violations.load
              end

              it { is_expected.to eq(overrides) }
            end
          end

          context 'when unviolated' do
            it { is_expected.to be_empty }
          end
        end

        context 'with any_merge_request rule' do
          let!(:approval_merge_request_rule) do
            create(
              :approval_merge_request_rule,
              :any_merge_request,
              merge_request: merge_request,
              scan_result_policy_read: policy,
              approvals_required: 1)
          end

          context 'when violated' do
            before do
              create(
                :scan_result_policy_violation,
                project: project,
                merge_request: merge_request,
                scan_result_policy_read: approval_merge_request_rule.scan_result_policy_read)
            end

            it { is_expected.to eq(overrides) }
          end

          context 'when unviolated' do
            it { is_expected.to be_empty }
          end

          context 'when rule is violated by other merge request' do
            let(:merge_request_2) do
              create(:merge_request, source_branch: 'test', source_project: project, target_project: project,
                state: :opened)
            end

            let(:project_approval_settings_2) do
              { prevent_approval_by_author: true,
                prevent_approval_by_commit_author: true,
                remove_approvals_with_new_commit: true,
                require_password_to_approve: true }
            end

            let(:policy_2) do
              create(:scan_result_policy_read, project: project, project_approval_settings: project_approval_settings_2)
            end

            let!(:approval_merge_request_rule_2) do
              create(:approval_merge_request_rule, :any_merge_request, merge_request: merge_request,
                scan_result_policy_read: policy_2, approvals_required: 1)
            end

            before do
              create(:scan_result_policy_violation, project: project, merge_request: merge_request,
                scan_result_policy_read: policy)

              create(:scan_result_policy_violation, project: project, merge_request: merge_request_2,
                scan_result_policy_read: policy_2)
            end

            it 'applies violations for the correct merge request' do
              is_expected.to eq(overrides)
            end
          end

          context 'with competing rules' do
            let(:other_policy) do
              create(
                :scan_result_policy_read,
                project: merge_request.target_project,
                project_approval_settings: project_approval_settings.transform_values { false },
                commits: :any)
            end

            let!(:approval_merge_request_rule) do
              create(
                :approval_merge_request_rule,
                :any_merge_request,
                merge_request: merge_request,
                scan_result_policy_read: policy,
                approvals_required: 1)
            end

            let!(:other_approval_merge_request_rule) do
              create(
                :approval_merge_request_rule,
                :any_merge_request,
                merge_request: merge_request,
                scan_result_policy_read: other_policy,
                approvals_required: 1)
            end

            before do
              [approval_merge_request_rule, other_approval_merge_request_rule].each do |rule|
                create(
                  :scan_result_policy_violation,
                  project: project,
                  merge_request: merge_request,
                  scan_result_policy_read: rule.scan_result_policy_read)
              end
            end

            it { is_expected.to eq(overrides) }
          end
        end
      end
    end
  end

  it_behaves_like 'an editable mentionable with EE-specific mentions' do
    subject { create(:merge_request, :simple) }

    let(:backref_text) { "merge request #{subject.to_reference}" }
    let(:set_mentionable_text) { ->(txt) { subject.description = txt } }
  end

  describe '#allow_external_status_checks?' do
    subject { merge_request.allow_external_status_checks? }

    let_it_be(:merge_request) { build_stubbed(:merge_request) }

    context 'when licensed feature `external_status_checks` is `false`' do
      before do
        stub_licensed_features(external_status_checks: false)
      end

      it { is_expected.to be false }
    end

    context 'when licensed feature `external_status_checks` is `true`' do
      before do
        stub_licensed_features(external_status_checks: true)
      end

      it { is_expected.to be true }
    end
  end

  describe '#participants' do
    subject(:participants) { merge_request.participants }

    context 'with approval rule' do
      before do
        approver = create(:approver, target: project)
        second_approver = create(:approver, target: project)

        create(:approval_merge_request_rule, merge_request: merge_request, users: [approver.user, second_approver.user])
      end

      it 'returns only the author as a participant' do
        expect(participants).to contain_exactly(merge_request.author)
      end
    end
  end

  describe '#has_denied_policies?', feature_category: :software_composition_analysis do
    let(:merge_request) { create(:ee_merge_request, :with_license_scanning_reports, source_project: project) }
    let(:apache) { build(:software_license, :apache_2_0) }

    let!(:head_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_license_scanning_feature_branch,
        project: project,
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha
      )
    end

    let!(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    before do
      allow_any_instance_of(Ci::CompareSecurityReportsService)
        .to receive(:execute).with(base_pipeline, head_pipeline).and_call_original
    end

    subject { merge_request.has_denied_policies? }

    context 'without existing pipeline' do
      it { is_expected.to be_falsey }
    end

    context 'with existing pipeline' do
      before do
        stub_licensed_features(license_scanning: true)
      end

      context 'without license_scanning report' do
        let(:merge_request) { create(:ee_merge_request, :with_dependency_scanning_reports, source_project: project) }

        it { is_expected.to be_falsey }
      end

      context 'with license_scanning report' do
        context 'without denied policy' do
          it { is_expected.to be_falsey }
        end

        context 'with allowed policy' do
          let(:allowed_policy) { build(:software_license_policy, :allowed, software_license: apache) }

          before do
            project.software_license_policies << allowed_policy
            synchronous_reactive_cache(merge_request)
          end

          it { is_expected.to be_falsey }
        end

        context 'with denied policy' do
          let(:denied_policy) { build(:software_license_policy, :denied, software_license: apache) }
          let(:merge_request) { create(:ee_merge_request, :with_cyclonedx_reports, source_project: project) }

          before do
            project.software_license_policies << denied_policy
            synchronous_reactive_cache(merge_request)

            create(:pm_package, name: "nokogiri", purl_type: "gem",
              other_licenses: [{ license_names: ["Apache-2.0"], versions: ["1.8.0"] }])
          end

          it { is_expected.to be_truthy }

          context 'with disabled licensed feature' do
            before do
              stub_licensed_features(license_scanning: false)
            end

            it { is_expected.to be_falsey }
          end

          context 'with License-Check enabled' do
            let!(:license_check) { create(:report_approver_rule, :license_scanning, merge_request: merge_request) }

            context 'when rule is not approved' do
              let(:merge_request) { create(:ee_merge_request, :with_cyclonedx_reports, source_project: project) }
              let(:denied_policy) { build(:software_license_policy, :denied, software_license: build(:software_license, :apache_2_0)) }

              before do
                allow_any_instance_of(ApprovalWrappedRule).to receive(:approved?).and_return(false)

                create(
                  :pm_package, name: "nokogiri", purl_type: "gem",
                  other_licenses: [{ license_names: ["Apache-2.0"], versions: ["1.8.0"] }]
                )
              end

              it { is_expected.to be_truthy }
            end

            context 'when rule is approved' do
              before do
                allow_any_instance_of(ApprovalWrappedRule).to receive(:approved?).and_return(true)
              end

              it { is_expected.to be_falsey }
            end
          end
        end
      end
    end

    context 'without license_scanning report in base pipeline' do
      before do
        stub_licensed_features(license_scanning: true)
        synchronous_reactive_cache(merge_request)
      end

      let(:merge_request) { create(:ee_merge_request, :with_cyclonedx_reports, source_project: project) }

      context 'when the base pipeline is nil' do
        let!(:base_pipeline) { nil }

        it { is_expected.to be_falsey }
      end

      context 'when the base pipeline does not have license reports' do
        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#enabled_reports' do
    where(:report_type, :with_reports, :feature) do
      :sast                | [:with_sast_reports]                                       | :sast
      :container_scanning  | [:with_container_scanning_reports]                         | :container_scanning
      :dast                | [:with_dast_reports]                                       | :dast
      :dependency_scanning | [:with_dependency_scanning_reports]                        | :dependency_scanning
      :license_scanning    | [:with_cyclonedx_reports]                                  | :license_scanning
      :coverage_fuzzing    | [:with_coverage_fuzzing_reports]                           | :coverage_fuzzing
      :secret_detection    | [:with_secret_detection_reports]                           | :secret_detection
      :api_fuzzing         | [:with_api_fuzzing_reports]                                | :api_fuzzing
    end

    with_them do
      subject { merge_request.enabled_reports[report_type] }

      before do
        stub_licensed_features({ feature => true })
      end

      context "when head pipeline has reports" do
        let(:merge_request) { create(:ee_merge_request, *with_reports, source_project: project) }

        it { is_expected.to be_truthy }
      end

      context "when head pipeline does not have reports" do
        let(:merge_request) { create(:ee_merge_request, source_project: project) }

        it { is_expected.to be_falsy }
      end
    end
  end

  describe '#approvals_before_merge' do
    where(:license_value, :db_value, :expected) do
      true  | 5   | 5
      true  | nil | nil
      false | 5   | nil
      false | nil | nil
    end

    with_them do
      let(:merge_request) { build(:merge_request, approvals_before_merge: db_value) }

      subject { merge_request.approvals_before_merge }

      before do
        stub_licensed_features(merge_request_approvers: license_value)
      end

      it { is_expected.to eq(expected) }
    end
  end

  describe '#has_security_reports?' do
    subject { merge_request.has_security_reports? }

    before do
      stub_licensed_features(dast: true)
    end

    context 'when head pipeline has security reports' do
      let(:merge_request) { create(:ee_merge_request, :with_dast_reports, source_project: project) }

      it { is_expected.to be_truthy }

      context 'when head pipeline is blocked by manual jobs' do
        before do
          merge_request.diff_head_pipeline.block!
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when head pipeline does not have security reports' do
      let(:merge_request) { create(:ee_merge_request, source_project: project) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#has_dependency_scanning_reports?' do
    subject { merge_request.has_dependency_scanning_reports? }

    before do
      stub_licensed_features(container_scanning: true)
    end

    context 'when head pipeline has dependency scannning reports' do
      let(:merge_request) { create(:ee_merge_request, :with_dependency_scanning_reports, source_project: project) }

      it { is_expected.to be_truthy }

      context 'when head pipeline is blocked by manual jobs' do
        before do
          merge_request.diff_head_pipeline.block!
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when head pipeline does not have dependency scanning reports' do
      let(:merge_request) { create(:ee_merge_request, source_project: project) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#has_container_scanning_reports?' do
    subject { merge_request.has_container_scanning_reports? }

    before do
      stub_licensed_features(container_scanning: true)
    end

    context 'when head pipeline has container scanning reports' do
      let(:merge_request) { create(:ee_merge_request, :with_container_scanning_reports, source_project: project) }

      it { is_expected.to be_truthy }

      context 'when head pipeline is blocked by manual jobs' do
        before do
          merge_request.diff_head_pipeline.block!
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when head pipeline does not have container scanning reports' do
      let(:merge_request) { create(:ee_merge_request, source_project: project) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#has_dast_reports?' do
    subject { merge_request.has_dast_reports? }

    before do
      stub_licensed_features(dast: true)
    end

    context 'when head pipeline has dast reports' do
      let(:merge_request) { create(:ee_merge_request, :with_dast_reports, source_project: project) }

      it { is_expected.to be_truthy }

      context 'when head pipeline is blocked by manual jobs' do
        before do
          merge_request.diff_head_pipeline.block!
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when pipeline ran for an older commit than the branch head' do
      let(:pipeline) { create(:ci_empty_pipeline, sha: 'notlatestsha') }
      let(:merge_request) { create(:ee_merge_request, source_project: project, head_pipeline: pipeline) }

      it { is_expected.to be_falsey }
    end

    context 'when head pipeline does not have dast reports' do
      let(:merge_request) { create(:ee_merge_request, source_project: project) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#has_metrics_reports?' do
    subject { merge_request.has_metrics_reports? }

    before do
      stub_licensed_features(metrics_reports: true)
    end

    context 'when head pipeline has metrics reports' do
      let(:merge_request) { create(:ee_merge_request, :with_metrics_reports, source_project: project) }

      it { is_expected.to be_truthy }
    end

    context 'when head pipeline does not have license scanning reports' do
      let(:merge_request) { create(:ee_merge_request, source_project: project) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#has_coverage_fuzzing_reports?' do
    subject { merge_request.has_coverage_fuzzing_reports? }

    before do
      stub_licensed_features(coverage_fuzzing: true)
    end

    context 'when head pipeline has coverage fuzzing reports' do
      let(:merge_request) { create(:ee_merge_request, :with_coverage_fuzzing_reports, source_project: project) }

      it { is_expected.to be_truthy }

      context 'when head pipeline is blocked by manual jobs' do
        before do
          merge_request.diff_head_pipeline.block!
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when head pipeline does not have coverage fuzzing reports' do
      let(:merge_request) { create(:ee_merge_request, source_project: project) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#has_api_fuzzing_reports?' do
    subject { merge_request.has_api_fuzzing_reports? }

    before do
      stub_licensed_features(api_fuzzing: true)
    end

    context 'when head pipeline has coverage fuzzing reports' do
      let(:merge_request) { create(:ee_merge_request, :with_api_fuzzing_reports, source_project: project) }

      it { is_expected.to be_truthy }

      context 'when head pipeline is blocked by manual jobs' do
        before do
          merge_request.diff_head_pipeline.block!
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'when head pipeline does not have coverage fuzzing reports' do
      let(:merge_request) { create(:ee_merge_request, source_project: project) }

      it { is_expected.to be_falsey }
    end
  end

  describe '#calculate_reactive_cache with current_user' do
    let(:current_user) { project.users.take }
    let(:merge_request) { create(:merge_request, source_project: project) }

    subject { merge_request.calculate_reactive_cache(service_class_name, current_user&.id) }

    context 'when given a known service class name' do
      let(:service_class_name) { 'Ci::CompareTestReportsService' }

      it 'does not raises a NameError exception' do
        allow_any_instance_of(service_class_name.constantize).to receive(:execute).and_return(nil)

        expect { subject }.not_to raise_error
      end
    end
  end

  describe '#compare_container_scanning_reports' do
    subject { merge_request.compare_container_scanning_reports(current_user) }

    let(:current_user) { project.users.first }
    let(:merge_request) { create(:merge_request, source_project: project) }

    let!(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_container_scanning_report,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    before do
      merge_request.update!(head_pipeline_id: head_pipeline.id)
    end

    context 'when head pipeline has container scanning reports' do
      let!(:head_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_container_scanning_report,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      context 'when reactive cache worker is parsing asynchronously' do
        it 'returns status' do
          expect(subject[:status]).to eq(:parsing)
        end
      end

      context 'when reactive cache worker is inline' do
        before do
          synchronous_reactive_cache(merge_request)
        end

        it 'returns status and data' do
          expect_any_instance_of(Ci::CompareSecurityReportsService)
              .to receive(:execute).with(base_pipeline, head_pipeline).and_call_original

          subject
        end

        context 'when cached results is not latest' do
          before do
            allow_any_instance_of(Ci::CompareSecurityReportsService)
                .to receive(:latest?).and_return(false)
          end

          it 'raises and InvalidateReactiveCache error' do
            expect { subject }.to raise_error(ReactiveCaching::InvalidateReactiveCache)
          end
        end
      end
    end
  end

  describe '#compare_secret_detection_reports' do
    subject { merge_request.compare_secret_detection_reports(current_user) }

    let(:current_user) { project.users.first }
    let(:merge_request) { create(:merge_request, source_project: project) }

    let!(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_secret_detection_report,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    before do
      merge_request.update!(head_pipeline_id: head_pipeline.id)
    end

    context 'when head pipeline has secret detection reports' do
      let!(:head_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_secret_detection_report,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      context 'when reactive cache worker is parsing asynchronously' do
        it 'returns status' do
          expect(subject[:status]).to eq(:parsing)
        end
      end

      context 'when reactive cache worker is inline' do
        before do
          synchronous_reactive_cache(merge_request)
        end

        it 'returns status and data' do
          expect_any_instance_of(Ci::CompareSecurityReportsService)
              .to receive(:execute).with(base_pipeline, head_pipeline).and_call_original

          subject
        end

        context 'when cached results is not latest' do
          before do
            allow_any_instance_of(Ci::CompareSecurityReportsService)
                .to receive(:latest?).and_return(false)
          end

          it 'raises and InvalidateReactiveCache error' do
            expect { subject }.to raise_error(ReactiveCaching::InvalidateReactiveCache)
          end
        end
      end
    end
  end

  describe '#compare_sast_reports' do
    subject { merge_request.compare_sast_reports(current_user) }

    let(:current_user) { project.users.first }
    let(:merge_request) { create(:merge_request, source_project: project) }

    let!(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_sast_report,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    before do
      merge_request.update!(head_pipeline_id: head_pipeline.id)
    end

    context 'when head pipeline has sast reports' do
      let!(:head_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_sast_report,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      context 'when reactive cache worker is parsing asynchronously' do
        it 'returns status' do
          expect(subject[:status]).to eq(:parsing)
        end
      end

      context 'when reactive cache worker is inline' do
        before do
          synchronous_reactive_cache(merge_request)
        end

        it 'returns status and data' do
          expect_any_instance_of(Ci::CompareSecurityReportsService)
              .to receive(:execute).with(base_pipeline, head_pipeline).and_call_original

          subject
        end

        context 'when cached results is not latest' do
          before do
            allow_any_instance_of(Ci::CompareSecurityReportsService)
                .to receive(:latest?).and_return(false)
          end

          it 'raises and InvalidateReactiveCache error' do
            expect { subject }.to raise_error(ReactiveCaching::InvalidateReactiveCache)
          end
        end
      end
    end
  end

  describe '#compare_license_scanning_reports', feature_category: :software_composition_analysis do
    subject { merge_request.compare_license_scanning_reports(current_user) }

    let(:current_user) { project.users.first }
    let(:merge_request) { create(:merge_request, source_project: project) }

    let!(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_cyclonedx_report,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    before do
      merge_request.update!(head_pipeline_id: head_pipeline.id)
    end

    context 'when head pipeline has cyclonedx reports' do
      let!(:head_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_cyclonedx_report,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      context 'when reactive cache worker is parsing asynchronously' do
        it 'returns status' do
          expect(subject[:status]).to eq(:parsing)
        end
      end

      context 'when reactive cache worker is inline' do
        before do
          synchronous_reactive_cache(merge_request)
        end

        it 'returns status and data' do
          expect_any_instance_of(Ci::CompareLicenseScanningReportsService)
            .to receive(:execute).with(base_pipeline, head_pipeline).and_call_original

          subject
        end

        context 'cache key includes sofware license policies' do
          let!(:license_1) { create(:software_license_policy, project: project) }
          let!(:license_2) { create(:software_license_policy, project: project) }

          it 'returns key with license information' do
            expect_any_instance_of(Ci::CompareLicenseScanningReportsService)
              .to receive(:execute).with(base_pipeline, head_pipeline).and_call_original

            expect(subject[:key].last).to include("software_license_policies/query-")
            expect(subject[:data]['existing_licenses'].last.dig('classification', 'approval_status')).to eq('unclassified')
          end
        end

        context 'when cached results is not latest' do
          before do
            allow_any_instance_of(Ci::CompareLicenseScanningReportsService)
              .to receive(:latest?).and_return(false)
          end

          it 'raises and InvalidateReactiveCache error' do
            expect { subject }.to raise_error(ReactiveCaching::InvalidateReactiveCache)
          end
        end
      end
    end

    context 'when head pipeline does not have cyclonedx reports' do
      let!(:head_pipeline) do
        create(
          :ci_pipeline,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      it 'returns status and error message' do
        expect(subject[:status]).to eq(:error)
        expect(subject[:status_reason]).to eq('This merge request does not have license scanning reports')
      end
    end

    context "when a cyclonedx report is produced from the head pipeline" do
      where(:pipeline_status, :build_types, :expected_status) do
        [
          [:blocked, [:container_scanning], :error],
          [:blocked, [:cyclonedx], :parsed],
          [:blocked, [:cyclonedx, :container_scanning], :parsed],
          [:blocked, [], :error],
          [:failed, [:container_scanning], :error],
          [:failed, [:cyclonedx], :parsed],
          [:failed, [:cyclonedx, :container_scanning], :parsed],
          [:failed, [], :error],
          [:running, [:container_scanning], :error],
          [:running, [:cyclonedx], :parsed],
          [:running, [:cyclonedx, :container_scanning], :parsed],
          [:running, [], :error],
          [:success, [:container_scanning], :error],
          [:success, [:cyclonedx], :parsed],
          [:success, [:cyclonedx, :container_scanning], :parsed],
          [:success, [], :error]
        ]
      end

      with_them do
        let!(:head_pipeline) { create(:ci_pipeline, pipeline_status, project: project, ref: merge_request.source_branch, sha: merge_request.diff_head_sha, builds: builds) }
        let(:builds) { build_types.map { |build_type| create(:ee_ci_build, build_type) } }

        before do
          synchronous_reactive_cache(merge_request)
        end

        specify { expect(subject[:status]).to eq(expected_status) }
      end
    end
  end

  describe '#compare_license_scanning_reports_collapsed', feature_category: :software_composition_analysis do
    subject(:report) { merge_request.compare_license_scanning_reports_collapsed(current_user) }

    let(:current_user) { project.users.first }

    let!(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_license_scanning_report,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    let!(:head_pipeline) do
      create(
        :ci_pipeline,
        project: project,
        ref: merge_request.source_branch,
        sha: merge_request.diff_head_sha
      )
    end

    context 'when service can be executed' do
      before do
        merge_request.update!(head_pipeline_id: head_pipeline.id)

        allow_next_instance_of(::Gitlab::LicenseScanning::SbomScanner) do |scanner|
          allow(scanner).to receive(:results_available?).and_return(true)
        end
      end

      it 'returns compared report' do
        expect(report[:status]).to eq(:parsing)
      end
    end

    context 'when head pipeline does not have license scanning reports' do
      it 'returns status and error message' do
        expect(subject[:status]).to eq(:error)
      end
    end
  end

  describe '#compare_metrics_reports' do
    subject { merge_request.compare_metrics_reports }

    let(:merge_request) { create(:merge_request, source_project: project) }

    let!(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_metrics_report,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    before do
      merge_request.update!(head_pipeline_id: head_pipeline.id)
    end

    context 'when head pipeline has metrics reports' do
      let!(:head_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_metrics_report,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      context 'when reactive cache worker is parsing asynchronously' do
        it 'returns status' do
          expect(subject[:status]).to eq(:parsing)
        end
      end

      context 'when reactive cache worker is inline' do
        before do
          synchronous_reactive_cache(merge_request)
        end

        it 'returns status and data' do
          expect_any_instance_of(Ci::CompareMetricsReportsService)
            .to receive(:execute).with(base_pipeline, head_pipeline).and_call_original

          subject
        end

        context 'when cached results is not latest' do
          before do
            allow_any_instance_of(Ci::CompareMetricsReportsService)
              .to receive(:latest?).and_return(false)
          end

          it 'raises and InvalidateReactiveCache error' do
            expect { subject }.to raise_error(ReactiveCaching::InvalidateReactiveCache)
          end
        end
      end
    end

    context 'when head pipeline does not have metrics reports' do
      let!(:head_pipeline) do
        create(
          :ci_pipeline,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      it 'returns status and error message' do
        expect(subject[:status]).to eq(:error)
        expect(subject[:status_reason]).to eq('This merge request does not have metrics reports')
      end
    end
  end

  describe '#compare_coverage_fuzzing_reports' do
    subject { merge_request.compare_coverage_fuzzing_reports(current_user) }

    let(:current_user) { project.users.first }
    let(:merge_request) { create(:merge_request, source_project: project) }

    let!(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_coverage_fuzzing_report,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    before do
      merge_request.update!(head_pipeline_id: head_pipeline.id)
    end

    context 'when head pipeline has coverage fuzzing reports' do
      let!(:head_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_coverage_fuzzing_report,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      context 'when reactive cache worker is parsing asynchronously' do
        it 'returns status' do
          expect(subject[:status]).to eq(:parsing)
        end
      end

      context 'when reactive cache worker is inline' do
        before do
          synchronous_reactive_cache(merge_request)
        end

        it 'returns status and data' do
          expect_any_instance_of(Ci::CompareSecurityReportsService)
            .to receive(:execute).with(base_pipeline, head_pipeline).and_call_original

          subject
        end

        context 'when cached results is not latest' do
          before do
            allow_any_instance_of(Ci::CompareSecurityReportsService)
                .to receive(:latest?).and_return(false)
          end

          it 'raises and InvalidateReactiveCache error' do
            expect { subject }.to raise_error(ReactiveCaching::InvalidateReactiveCache)
          end
        end
      end
    end
  end

  describe '#compare_api_fuzzing_reports' do
    subject { merge_request.compare_api_fuzzing_reports(current_user) }

    let(:current_user) { project.users.first }
    let(:merge_request) { create(:merge_request, source_project: project) }

    let!(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_api_fuzzing_report,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    before do
      merge_request.update!(head_pipeline_id: head_pipeline.id)
    end

    context 'when head pipeline has api fuzzing reports' do
      let!(:head_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_api_fuzzing_report,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      context 'when reactive cache worker is parsing asynchronously' do
        it 'returns status' do
          expect(subject[:status]).to eq(:parsing)
        end
      end

      context 'when reactive cache worker is inline' do
        before do
          synchronous_reactive_cache(merge_request)
        end

        it 'returns status and data' do
          expect_any_instance_of(Ci::CompareSecurityReportsService)
            .to receive(:execute).with(base_pipeline, head_pipeline).and_call_original

          subject
        end

        context 'when cached results is not latest' do
          before do
            allow_any_instance_of(Ci::CompareSecurityReportsService)
                .to receive(:latest?).and_return(false)
          end

          it 'raises an InvalidateReactiveCache error' do
            expect { subject }.to raise_error(ReactiveCaching::InvalidateReactiveCache)
          end
        end
      end
    end
  end

  describe '#use_merge_base_pipeline_for_comparison?' do
    let(:merge_request) { create(:merge_request, :with_codequality_reports, source_project: project) }

    subject { merge_request.use_merge_base_pipeline_for_comparison?(service_class) }

    context 'when service class is Ci::CompareMetricsReportsService' do
      let(:service_class) { ::Ci::CompareMetricsReportsService }

      it { is_expected.to eq(true) }
    end

    context 'when service class is Ci::CompareCodequalityReportsService' do
      let(:service_class) { ::Ci::CompareCodequalityReportsService }

      it { is_expected.to eq(true) }
    end

    context 'when service class is Ci::CompareSecurityReportsService' do
      let(:service_class) { ::Ci::CompareSecurityReportsService }

      it { is_expected.to eq(true) }
    end

    context 'when service class is Ci::CompareLicenseScanningReportsCollapsedService' do
      let(:service_class) { ::Ci::CompareLicenseScanningReportsCollapsedService }

      it { is_expected.to eq(true) }
    end

    context 'when service class is Ci::CompareLicenseScanningReportsService' do
      let(:service_class) { ::Ci::CompareLicenseScanningReportsService }

      it { is_expected.to eq(true) }
    end

    context 'when service class is different' do
      let(:service_class) { ::Ci::GenerateCoverageReportsService }

      it { is_expected.to eq(false) }
    end
  end

  describe '#approver_group_ids=' do
    it 'create approver_groups' do
      group = create :group
      group1 = create :group

      merge_request = create :merge_request

      merge_request.approver_group_ids = "#{group.id}, #{group1.id}"
      merge_request.save!

      expect(merge_request.approver_groups.map(&:group)).to match_array([group, group1])
    end
  end

  describe '#predefined_variables' do
    context 'when merge request has approver feature' do
      before do
        stub_licensed_features(merge_request_approvers: true)
      end

      context 'without any rules' do
        it 'includes variable CI_MERGE_REQUEST_APPROVED=true' do
          expect(merge_request.predefined_variables.to_hash).to include('CI_MERGE_REQUEST_APPROVED' => 'true')
        end

        context 'when the mr is temporarily unapproved' do
          it 'does not include variable CI_MERGE_REQUEST_APPROVED' do
            expect(merge_request.approval_state).to receive(:temporarily_unapproved?).and_return(true)

            expect(merge_request.predefined_variables.to_hash.keys).not_to include('CI_MERGE_REQUEST_APPROVED')
          end
        end
      end

      context 'with a rule' do
        let(:approver) { create(:user) }
        let!(:rule) { create(:approval_merge_request_rule, merge_request: merge_request, approvals_required: 1, users: [approver]) }

        context 'that has been approved' do
          it 'includes variable CI_MERGE_REQUEST_APPROVED=true' do
            create(:approval, merge_request: merge_request, user: approver)

            expect(merge_request.predefined_variables.to_hash).to include('CI_MERGE_REQUEST_APPROVED' => 'true')
          end
        end

        context 'that has not been approved' do
          it 'does not include variable CI_MERGE_REQUEST_APPROVED' do
            expect(merge_request.predefined_variables.to_hash.keys).not_to include('CI_MERGE_REQUEST_APPROVED')
          end
        end
      end
    end

    context 'when merge request does not have approver feature' do
      before do
        stub_licensed_features(merge_request_approvers: false)
      end

      it 'does not include variable CI_MERGE_REQUEST_APPROVED' do
        expect(merge_request.predefined_variables.to_hash.keys).not_to include('CI_MERGE_REQUEST_APPROVED')
      end
    end
  end

  describe '#mergeable?' do
    context 'with skip_approved_check option' do
      before do
        allow(subject).to receive_messages(mergeable_ci_state?: true,
          mergeable_discussions_state?: true,
          check_mergeability: nil,
          can_be_merged?: true,
          broken?: false)
      end

      where(:approved_state, :skip_approved_check, :expected_mergeable) do
        false | false | false
        false | true  | true
        true  | false | true
        true  | true  | true
      end

      with_them do
        it 'overrides mergeable?' do
          allow(merge_request).to receive(:approved?) { approved_state }

          expect(merge_request.mergeable?(skip_approved_check: skip_approved_check)).to eq(expected_mergeable)
        end
      end
    end
  end

  describe '#skipped_mergeable_checks' do
    subject { build_stubbed(:merge_request).skipped_mergeable_checks(options) }

    let(:options) { { auto_merge_strategy: auto_merge_strategy } }

    before do
      stub_feature_flags(additional_merge_when_checks_ready: feature_flag)
    end

    where(:auto_merge_strategy, :skip_approved_check, :skip_draft_check, :skip_blocked_check, :skip_discussions_check, :skip_external_status_check, :feature_flag) do
      ''                                                      | false | false | false | false | false | true
      AutoMergeService::STRATEGY_MERGE_WHEN_PIPELINE_SUCCEEDS | false | false | false | false | false | true
      AutoMergeService::STRATEGY_MERGE_WHEN_CHECKS_PASS       | true | true | true | true | true | true
      AutoMergeService::STRATEGY_MERGE_WHEN_CHECKS_PASS       | true | false | false | false | false | false
    end

    with_them do
      it {
        is_expected.to include(skip_approved_check: skip_approved_check, skip_draft_check: skip_draft_check,
          skip_blocked_check: skip_blocked_check, skip_discussions_check: skip_discussions_check,
          skip_external_status_check: skip_external_status_check)
      }
    end
  end

  describe '#mergeable_state?' do
    subject { merge_request.mergeable_state?(**params) }

    let(:params) { {} }
    let(:project_with_approver) { create(:project, :repository) }
    let(:merge_request) { create(:merge_request, source_project: project_with_approver, target_project: project_with_approver) }

    let_it_be(:user) { create(:user) }

    context 'when using approvals' do
      before do
        merge_request.target_project.update!(approvals_before_merge: 1)
        project.add_developer(user)
      end

      context 'when not approved' do
        it 'is not mergeable' do
          is_expected.to be_falsey
        end
      end

      context 'when approved' do
        before do
          merge_request.approvals.create!(user: user)
        end

        it 'is mergeable' do
          is_expected.to be_truthy
        end
      end
    end

    context 'when validating jira associations' do
      let_it_be_with_reload(:project_jira) { create(:project, :repository, :with_jira_integration) }
      let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project_jira, target_project: project_jira) }

      before do
        allow(merge_request.project).to receive(:prevent_merge_without_jira_issue?).and_return(true)
      end

      context 'when the merge request does not reference a jira issue' do
        before do
          merge_request.update!(description: '')
        end

        it 'is not mergeable' do
          is_expected.to be_falsey
        end
      end

      context 'when the merge request references a jira issue' do
        before do
          merge_request.update!(description: 'PROJECT-1')
        end

        it 'is mergeable' do
          is_expected.to be_truthy
        end
      end
    end

    context 'when using external status checks' do
      let(:any_external_status_checks_not_passed?) { false }

      before do
        allow(merge_request).to receive(:only_allow_merge_if_all_status_checks_passed_enabled?).and_return(true)
        allow(merge_request.project).to receive(:only_allow_merge_if_all_status_checks_passed).and_return(true)
        allow(merge_request.project).to receive(:any_external_status_checks_not_passed?)
                            .and_return(any_external_status_checks_not_passed?)
        stub_licensed_features(external_status_checks: true)
      end

      context 'when external checks pass' do
        let!(:status_code) { create(:status_check_response, status: :passed, merge_request: merge_request) }

        it 'is mergeable' do
          is_expected.to be_truthy
        end
      end

      context 'when external status checks are not passed' do
        let(:any_external_status_checks_not_passed?) { true }

        let!(:status_code) { create(:status_check_response, status: :failed, merge_request: merge_request) }

        it 'is not mergeable' do
          is_expected.to be_falsey
        end

        context 'when skip external status checks is true' do
          let(:params) { { skip_external_status_check: true } }

          it 'is mergeable' do
            is_expected.to be_truthy
          end
        end
      end
    end

    context 'when blocking merge requests' do
      before do
        stub_licensed_features(blocking_merge_requests: true)
      end

      context 'when the merge request is blocked' do
        let(:merge_request) { create(:merge_request, :blocked, source_project: project, target_project: project) }

        it 'is not mergeable' do
          is_expected.to be_falsey
        end

        context 'when skip blocked check' do
          let(:params) { { skip_blocked_check: true } }

          it 'is mergeable' do
            is_expected.to be_truthy
          end
        end
      end

      context 'when merge request is not blocked' do
        it 'is mergeable' do
          is_expected.to be_truthy
        end
      end
    end
  end

  describe '#on_train?' do
    subject { merge_request.on_train? }

    context 'when the merge request is on a merge train' do
      let(:merge_request) do
        create(:merge_request, :on_train, source_project: project, target_project: project)
      end

      it { is_expected.to be_truthy }
    end

    context 'when the merge request was on a merge train' do
      let(:merge_request) do
        create(:merge_request, :on_train,
          status: MergeTrains::Car.state_machines[:status].states[:merged].value,
          source_project: project, target_project: project)
      end

      it { is_expected.to be_falsy }
    end

    context 'when the merge request is not on a merge train' do
      let(:merge_request) do
        create(:merge_request, source_project: project, target_project: project)
      end

      it { is_expected.to be_falsy }
    end
  end

  describe 'review time sorting' do
    def create_mr(metrics_data = {})
      create(:merge_request, :with_productivity_metrics, metrics_data: metrics_data)
    end

    it 'orders by first_comment_at or first_approved_at whatever is earlier' do
      mr1 = create_mr(first_comment_at: 1.day.ago)
      mr2 = create_mr(first_comment_at: 3.days.ago)
      mr3 = create_mr(first_approved_at: 5.days.ago)
      mr4 = create_mr(first_comment_at: 1.day.ago, first_approved_at: 4.days.ago)
      mr5 = create_mr(first_comment_at: nil, first_approved_at: nil)

      expect(described_class.order_review_time_desc).to match([mr3, mr4, mr2, mr1, mr5])
      expect(described_class.sort_by_attribute('review_time_desc')).to match([mr3, mr4, mr2, mr1, mr5])
    end
  end

  describe '#security_reports_up_to_date?' do
    let(:merge_request) do
      create(
        :ee_merge_request,
        source_project: project,
        source_branch: 'feature1',
        target_branch: project.default_branch
      )
    end

    before do
      create(
        :ee_ci_pipeline,
        :with_sast_report,
        project: project,
        ref: merge_request.target_branch
      )
    end

    subject { merge_request.security_reports_up_to_date? }

    context 'when the target branch security reports are up to date' do
      it { is_expected.to be true }
    end

    context 'when the target branch security reports are out of date' do
      before do
        create(:ee_ci_pipeline, :failed, project: project, ref: merge_request.target_branch)
      end

      it { is_expected.to be false }
    end
  end

  describe '#audit_details' do
    it 'equals to the title' do
      merge_request = create(:merge_request, title: 'I am a title')

      expect(merge_request.audit_details).to eq(merge_request.title)
    end
  end

  describe '#validate_reviewer_length' do
    let(:reviewer1) { create(:user) }
    let(:reviewer2) { create(:user) }
    let(:reviewer3) { create(:user) }

    subject { create(:merge_request) }

    before do
      stub_const("Issuable::MAX_NUMBER_OF_ASSIGNEES_OR_REVIEWERS", 2)
    end

    it 'will not exceed the reviewer limit' do
      expect do
        subject.update!(reviewers: [reviewer1, reviewer2, reviewer3])
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe '#sync_project_approval_rules_for_policy_configuration' do
    let_it_be(:merge_request) { create(:ee_merge_request, source_project: project) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let_it_be(:project_approval_rule_without_configuration) { create(:approval_project_rule, project: project) }

    let_it_be(:project_approval_rule) do
      create(:approval_project_rule, :scan_finding,
        project: project,
        security_orchestration_policy_configuration: policy_configuration,
        scanners: %w[sast],
        approvals_required: 2,
        scan_result_policy_read: create(:scan_result_policy_read)
      )
    end

    subject do
      merge_request.sync_project_approval_rules_for_policy_configuration(policy_configuration.id)
    end

    it 'creates approval rules for project' do
      subject

      expect(merge_request.approval_rules.first.approval_project_rule).to eq(project_approval_rule)
    end

    it 'does not create approval rules for other configuration' do
      subject

      expect(merge_request.approval_rules.map(&:approval_project_rule)).not_to include(project_approval_rule_without_configuration)
    end

    context 'when mr approval rules already exist' do
      let_it_be(:mr_approval_rule) do
        create(:report_approver_rule, :scan_finding,
          merge_request: merge_request,
          approvals_required: 1
        )
      end

      let_it_be(:approval_rule_source) do
        create(:approval_merge_request_rule_source,
          approval_merge_request_rule: mr_approval_rule,
          approval_project_rule: project_approval_rule
        )
      end

      it 'updates approval rule' do
        subject

        expect(mr_approval_rule.reload.approvals_required).to eq(2)
      end
    end

    context 'when merge request is already merged' do
      let_it_be(:merge_request) { create(:ee_merge_request, source_project: project, state: :merged) }

      it 'does not create or update approval rule' do
        subject

        expect(merge_request.approval_rules).to be_empty
      end
    end
  end

  describe '#reset_required_approvals' do
    subject(:execute) { merge_request.reset_required_approvals(approval_rules) }

    let_it_be(:merge_request) { create(:ee_merge_request, source_project: project) }
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project) }
    let_it_be(:scan_finding_project_rule) do
      create(:approval_project_rule, :scan_finding, project: project, scanners: %w[sast], approvals_required: 2,
        security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:license_project_rule) do
      create(:approval_project_rule, :license_scanning, project: project, approvals_required: 2,
        security_orchestration_policy_configuration: policy_configuration)
    end

    let_it_be(:other_project_rule) do
      create(:approval_project_rule, :scan_finding, project: project, scanners: %w[sast], approvals_required: 2,
        security_orchestration_policy_configuration: policy_configuration)
    end

    context 'when report_approver_rule has a project source' do
      let_it_be(:approval_rules) do
        [
          create(:report_approver_rule, :scan_finding, merge_request: merge_request, approvals_required: 0,
            approval_project_rule: scan_finding_project_rule),
          create(:report_approver_rule, :license_scanning, merge_request: merge_request, approvals_required: 0,
            approval_project_rule: license_project_rule)
        ]
      end

      let_it_be(:other_approval_rule_with_project_source) do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request, approvals_required: 0,
          approval_project_rule: other_project_rule)
      end

      it 'resets the approvals_required for the provided approval_rules to match the project rules' do
        expect { execute }.to change { approval_rules.first.reload.approvals_required }.from(0).to(2)
          .and change { approval_rules.second.reload.approvals_required }.from(0).to(2)
      end

      it 'does not reset other approval rules' do
        expect { execute }.not_to change { other_approval_rule_with_project_source.reload.approvals_required }
      end

      context 'when merge request is already merged' do
        before do
          merge_request.update!(state: 'merged')
        end

        after do
          merge_request.update!(state: 'opened')
        end

        it 'does not update the approval rules' do
          expect { execute }.to not_change { approval_rules.first.reload.approvals_required }
            .and not_change { approval_rules.second.reload.approvals_required }
        end
      end
    end

    context "when report_approver_rule doesn't have a project source" do
      let_it_be(:approval_rules) do
        [create(:report_approver_rule, :scan_finding, merge_request: merge_request, approvals_required: 0)]
      end

      it "doesn't reset the approval_rules" do
        expect { execute }.not_to change { approval_rules.first.reload }
      end
    end
  end

  context 'scopes' do
    let_it_be(:merge_request) { create(:ee_merge_request) }
    let_it_be(:merge_request_with_head_pipeline) { create(:ee_merge_request, :with_metrics_reports) }

    describe '.with_head_pipeline' do
      it 'returns MRs that have a head pipeline' do
        expect(described_class.with_head_pipeline).to eq([merge_request_with_head_pipeline])
      end
    end

    describe '.not_merged' do
      let(:opened_merge_request) { create(:merge_request, :opened) }
      let(:merged_merge_request) { create(:merge_request, :merged) }
      let(:closed_merge_request) { create(:merge_request, :closed) }
      let(:locked_merge_request) { create(:merge_request, :locked) }

      it 'returns everything except the merged mr' do
        expect(described_class.not_merged).to contain_exactly(merge_request, merge_request_with_head_pipeline, opened_merge_request, closed_merge_request, locked_merge_request)
      end
    end

    describe '.with_applied_scan_result_policies' do
      let_it_be(:scan_finding_approval_rule) { create(:report_approver_rule, :code_coverage) }
      let_it_be(:code_coverage_approval_rule) { create(:report_approver_rule, :scan_finding) }

      it 'returns MRs that have applied scan result policies' do
        expect(described_class.with_applied_scan_result_policies).to eq([code_coverage_approval_rule.merge_request])
      end
    end

    describe '.for_projects_with_security_policy_project' do
      let_it_be(:security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration) }

      let_it_be(:merge_request_with_security_policy_project) do
        create(:ee_merge_request, source_project: security_orchestration_policy_configuration.project)
      end

      let_it_be(:merge_request_without_security_policy_project) { create(:ee_merge_request) }

      it 'returns MRs for projects with security policy project on target project' do
        expect(described_class.for_projects_with_security_policy_project).to eq(
          [merge_request_with_security_policy_project])
      end
    end
  end

  context 'after_commit hooks' do
    describe 'create_pending_status_check_responses' do
      subject(:create_merge_request) { create(:merge_request, source_project: project, target_project: project, state: :opened) }

      let_it_be(:status_check) { create(:external_status_check, project: project) }
      let_it_be(:another_status_check) { create(:external_status_check, project: project) }
      let(:merge_request) { described_class.last }

      context 'when project can have status checks' do
        before do
          stub_licensed_features(external_status_checks: true)
        end

        it 'creates `pending` status check responses' do
          expect(ComplianceManagement::PendingStatusCheckWorker).to receive(:perform_async).and_call_original

          create_merge_request
        end
      end

      context 'when project can not have status checks' do
        it 'does not create status check responses' do
          expect(ComplianceManagement::PendingStatusCheckWorker).not_to receive(:perform_async)

          create_merge_request
        end
      end
    end
  end

  context 'after_update hooks' do
    describe 'sync_merge_request_compliance_violation' do
      let_it_be(:merge_request) do
        create(:merge_request, source_project: project, target_project: project, state: :merged, title: 'old MR title')
      end

      let_it_be(:compliance_violation) do
        create(:compliance_violation, :approved_by_committer, severity_level: :low, merge_request: merge_request, title: 'old MR title')
      end

      it "calls sync_merge_request_compliance_violation when the MR title is updated" do
        expect(merge_request.compliance_violations.pluck(:title)).to contain_exactly('old MR title')
        expect(merge_request).to receive(:sync_merge_request_compliance_violation).and_call_original

        merge_request.update_attribute(:title, "new MR title")

        expect(merge_request.compliance_violations.pluck(:title)).to contain_exactly('new MR title')
      end

      it "does not call sync_merge_request_compliance_violation when the MR title is not updated" do
        expect(merge_request).not_to receive(:sync_merge_request_compliance_violation)

        merge_request.update_attribute(:milestone, Milestone.last)
      end
    end
  end

  describe '#merge_train' do
    subject { merge_request.merge_train }

    before do
      allow(project).to receive(:merge_trains_enabled?).and_return(setting)
    end

    context 'with MergeTrains disabled' do
      let(:setting) { false }

      it { is_expected.to be_nil }
    end

    context 'with MergeTrains enabled' do
      let(:setting) { true }

      it { is_expected.to be_a(MergeTrains::Train) }
    end
  end

  describe '#should_be_rebased?' do
    subject { merge_request.should_be_rebased? }

    shared_examples 'ff car on train' do
      context 'when MR is on an up-to-date fast-forward merge train' do
        before do
          car = create(:merge_train_car, merge_request: merge_request)

          merge_request.update!(
            merge_params: merge_request.merge_params.merge(
              'train_ref' => { 'commit_sha' => car.pipeline.sha }
            )
          )
        end

        it { is_expected.to eq false }
      end
    end

    context 'when MR source branch needs to be rebased to be merged' do
      before do
        stub_foss_conditions_met
      end

      context 'when the project is using ff trains' do
        before do
          allow(MergeTrains::Train).to receive(:project_using_ff?).and_return(true)
        end

        it { is_expected.to eq false }

        it_behaves_like 'ff car on train'
      end

      context 'when project not using ff trains' do
        before do
          allow(MergeTrains::Train).to receive(:project_using_ff?).and_return(false)
        end

        it { is_expected.to eq true }

        it_behaves_like 'ff car on train'
      end
    end

    def stub_foss_conditions_met
      allow(project).to receive(:ff_merge_must_be_possible?).and_return(true)
      allow(merge_request).to receive(:ff_merge_possible?).and_return(false)
    end
  end

  describe '#comparison_base_pipeline' do
    let_it_be(:project) { create(:project, :public, :repository) }
    let_it_be_with_refind(:merge_request) do
      create(:merge_request, :with_merge_request_pipeline, source_project: project)
    end

    let_it_be(:base_pipeline) do
      create(:ci_pipeline,
        :with_test_reports,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha
      )
    end

    subject(:pipeline) { merge_request.comparison_base_pipeline(service_class) }

    context 'when the service class is not `Ci::CompareSecurityReportsService`' do
      let(:service_class) { ::Ci::CompareCodequalityReportsService }

      before do
        allow(merge_request).to receive_messages(merge_base_pipeline: nil, base_pipeline: nil)
      end

      it 'follows the normal execution order' do
        pipeline

        expect(merge_request).to have_received(:merge_base_pipeline)
        expect(merge_request).to have_received(:base_pipeline)
      end
    end

    context 'when the service class is `Ci::CompareSecurityReportsService`' do
      let(:service_class) { ::Ci::CompareSecurityReportsService }

      before do
        merge_request.update_head_pipeline
      end

      context 'when there are merge base pipelines' do
        let_it_be(:old_merge_base_pipeline) do
          create(:ci_pipeline,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.target_branch_sha
          )
        end

        let_it_be(:most_recent_merge_base_pipeline) do
          create(:ci_pipeline,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.target_branch_sha
          )
        end

        context 'when all pipelines have security reports' do
          before do
            build_1 = build(:ci_build,
              :sast_report,
              pipeline: old_merge_base_pipeline,
              project: project)

            build_2 = build(:ci_build,
              :sast_report,
              pipeline: most_recent_merge_base_pipeline,
              project: project)

            old_merge_base_pipeline.builds << build_1
            most_recent_merge_base_pipeline.builds << build_2
          end

          it 'returns the most recent merge base pipeline' do
            expect(pipeline).to eq(most_recent_merge_base_pipeline)
          end
        end

        context 'when the most recent pipeline does not have security reports' do
          before do
            build = build(:ci_build,
              :sast_report,
              pipeline: old_merge_base_pipeline,
              project: project)

            old_merge_base_pipeline.builds << build
          end

          it 'returns the latest merge base pipeline with security reports' do
            expect(pipeline).to eq(old_merge_base_pipeline)
          end
        end
      end

      context 'when there is no merge base pipeline' do
        let_it_be(:old_base_pipeline) do
          create(:ci_pipeline,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_base_sha
          )
        end

        let_it_be(:most_recent_base_pipeline) do
          create(:ci_pipeline,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_base_sha
          )
        end

        context 'when all pipelines have security reports' do
          before do
            build_1 = build(:ci_build,
              :sast_report,
              pipeline: old_base_pipeline,
              project: project)

            build_2 = build(:ci_build,
              :sast_report,
              pipeline: most_recent_base_pipeline,
              project: project)

            old_base_pipeline.builds << build_1
            most_recent_base_pipeline.builds << build_2
          end

          it 'returns the most recent base pipeline' do
            expect(pipeline).to eq(most_recent_base_pipeline)
          end
        end

        context 'when the most recent pipeline does not have security reports' do
          before do
            build = build(:ci_build,
              :sast_report,
              pipeline: old_base_pipeline,
              project: project)

            old_base_pipeline.builds << build
          end

          it 'returns the latest base pipeline with security reports' do
            expect(pipeline).to eq(old_base_pipeline)
          end
        end
      end
    end
  end

  describe '#latest_comparison_pipeline_with_sbom_reports' do
    let_it_be(:project) { create(:project, :public, :repository) }
    let_it_be_with_refind(:merge_request) do
      create(:merge_request, :with_merge_request_pipeline, source_project: project)
    end

    let_it_be(:base_pipeline) do
      create(
        :ci_pipeline,
        :with_test_reports,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha)
    end

    subject(:pipeline) { merge_request.latest_comparison_pipeline_with_sbom_reports }

    before do
      merge_request.update_head_pipeline
    end

    context 'when there are merge base pipelines' do
      let_it_be(:old_merge_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_cyclonedx_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.target_branch_sha)
      end

      let_it_be(:most_recent_merge_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_cyclonedx_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.target_branch_sha)
      end

      context 'when all pipelines have SBOM artifacts' do
        it 'returns the most recent merge base pipeline' do
          expect(pipeline).to eq(most_recent_merge_base_pipeline)
        end
      end

      context 'when the most recent pipeline does not have an SBOM artifact' do
        before do
          most_recent_merge_base_pipeline.job_artifacts.cyclonedx.delete_all
        end

        it 'returns the latest merge base pipeline with an SBOM artifact' do
          expect(pipeline).to eq(old_merge_base_pipeline)
        end
      end
    end

    context 'when there is no merge base pipeline' do
      let_it_be(:old_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_cyclonedx_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.diff_base_sha)
      end

      let_it_be(:most_recent_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_cyclonedx_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.diff_base_sha)
      end

      context 'when all pipelines have SBOM artifacts' do
        it 'returns the most recent base pipeline' do
          expect(pipeline).to eq(most_recent_base_pipeline)
        end
      end

      context 'when the most recent pipeline does not have an SBOM artifact' do
        before do
          most_recent_base_pipeline.job_artifacts.cyclonedx.delete_all
        end

        it 'returns the latest base pipeline with an SBOM artifact' do
          expect(pipeline).to eq(old_base_pipeline)
        end
      end
    end
  end

  describe '#diff_head_pipeline?' do
    let_it_be_with_refind(:merge_request) do
      create(:merge_request, :with_merge_request_pipeline, source_project: project)
    end

    subject(:diff_head_pipeline) { merge_request.diff_head_pipeline?(pipeline) }

    context 'when the pipeline is the head pipeline' do
      let_it_be(:pipeline) do
        create(:ee_ci_pipeline,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha
        )
      end

      it { is_expected.to be_truthy }
    end

    context 'when the pipeline is merged_results_pipeline' do
      let_it_be(:pipeline) do
        create(:ci_pipeline, :merged_result_pipeline, :success, project: project, merge_request: merge_request)
      end

      it { is_expected.to be_truthy }
    end

    context 'when the pipeline is base_pipeline' do
      let_it_be(:pipeline) do
        create(:ee_ci_pipeline,
          project: project,
          ref: merge_request.source_branch,
          sha: merge_request.diff_base_sha
        )
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#latest_scan_finding_comparison_pipeline' do
    let_it_be(:project) { create(:project, :public, :repository) }
    let_it_be_with_refind(:merge_request) do
      create(:merge_request, :with_merge_request_pipeline, source_project: project)
    end

    let_it_be(:base_pipeline) do
      create(
        :ee_ci_pipeline,
        :with_dependency_scanning_report,
        project: project,
        ref: merge_request.target_branch,
        sha: merge_request.diff_base_sha)
    end

    subject(:pipeline) { merge_request.latest_scan_finding_comparison_pipeline }

    before do
      merge_request.update_head_pipeline
    end

    context 'when there are merge base pipelines' do
      let_it_be(:old_merge_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :success,
          :with_dependency_scanning_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.target_branch_sha)
      end

      let_it_be(:most_recent_merge_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :success,
          :with_dependency_scanning_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.target_branch_sha)
      end

      context 'when all pipelines have security reports' do
        it 'returns the most recent merge base pipeline' do
          expect(pipeline).to eq(most_recent_merge_base_pipeline)
        end
      end

      context 'when the most recent pipeline does not have security reports' do
        before do
          most_recent_merge_base_pipeline.job_artifacts.security_reports.delete_all
        end

        context 'when other merge base pipeline has security reports' do
          it 'returns the latest merge base pipeline with security reports' do
            expect(pipeline).to eq(old_merge_base_pipeline)
          end
        end

        context 'when no other merge base pipeline has security reports' do
          before do
            old_merge_base_pipeline.job_artifacts.security_reports.delete_all
          end

          context 'when base pipeline has security reports' do
            it 'returns the base pipeline' do
              expect(pipeline).to eq(base_pipeline)
            end
          end

          context 'when no base pipeline has security reports' do
            before do
              base_pipeline.job_artifacts.security_reports.delete_all

              most_recent_merge_base_pipeline.update!(status: :manual)
            end

            it 'returns nil' do
              expect(pipeline).to be_nil
            end
          end
        end
      end
    end

    context 'when there is no merge base pipeline' do
      let_it_be_with_refind(:old_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_dependency_scanning_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.diff_base_sha)
      end

      let_it_be_with_refind(:most_recent_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :with_dependency_scanning_report,
          project: project,
          ref: merge_request.target_branch,
          sha: merge_request.diff_base_sha)
      end

      context 'when all pipelines have security reports' do
        it 'returns the most recent base pipeline' do
          expect(pipeline).to eq(most_recent_base_pipeline)
        end
      end

      context 'when the most recent pipeline does not have security reports' do
        before do
          most_recent_base_pipeline.job_artifacts.security_reports.delete_all
        end

        it 'returns the latest base pipeline with security reports' do
          expect(pipeline).to eq(old_base_pipeline)
        end

        context 'when no base pipeline has security reports' do
          before do
            base_pipeline.job_artifacts.security_reports.delete_all
            old_base_pipeline.job_artifacts.security_reports.delete_all
            most_recent_base_pipeline.job_artifacts.security_reports.delete_all
          end

          it 'returns nil' do
            expect(pipeline).to be_nil
          end
        end

        context 'when no base pipeline has completed' do
          before do
            base_pipeline.update!(status: :waiting_for_resource)
            old_base_pipeline.update!(status: :waiting_for_resource)
            most_recent_base_pipeline.update!(status: :waiting_for_resource)
          end

          context 'when comparison prior to pipeline completion is disabled' do
            before do
              stub_feature_flags(mr_show_reports_immediately: false)
            end

            it 'returns nil' do
              expect(pipeline).to be_nil
            end
          end

          context 'when comparison prior to pipeline completion is enabled' do
            it 'returns the most recent base pipeline' do
              expect(pipeline).to eq(old_base_pipeline)
            end
          end
        end
      end
    end
  end

  describe '#blocking_merge_requests_feature_available?' do
    let(:merge_request) { build_stubbed(:merge_request) }

    subject(:result) { merge_request.blocking_merge_requests_feature_available? }

    before do
      stub_licensed_features(blocking_merge_requests: blocking_merge_requests_enabled)
    end

    context 'when blocking_merge_requests feature is enabled' do
      let(:blocking_merge_requests_enabled) { true }

      it { is_expected.to eq(true) }
    end

    context 'when blocking_merge_requests feature is disabled' do
      let(:blocking_merge_requests_enabled) { false }

      it { is_expected.to eq(false) }
    end
  end

  describe '#license_scanning_feature_available?' do
    let(:merge_request) { build_stubbed(:merge_request) }

    subject(:result) { merge_request.license_scanning_feature_available? }

    before do
      stub_licensed_features(license_scanning: license_scanning_enabled)
    end

    context 'when license_scanning feature is enabled' do
      let(:license_scanning_enabled) { true }

      it { is_expected.to eq(true) }
    end

    context 'when license_scanning feature is disabled' do
      let(:license_scanning_enabled) { false }

      it { is_expected.to eq(false) }
    end
  end

  describe '#notify_approvers' do
    let_it_be(:merge_request) { create(:merge_request) }
    let_it_be(:approvers) { create_list(:user, 2) }
    let_it_be(:approval_rule) { create(:approval_merge_request_rule, merge_request: merge_request, users: approvers) }

    it 'calls NotificationService.added_as_approver' do
      expect_any_instance_of(EE::NotificationService).to receive(:added_as_approver)
        .with(merge_request.wrapped_approval_rules.flat_map(&:approvers), merge_request)

      merge_request.notify_approvers
    end
  end

  describe '#has_changes_requested?' do
    it { expect(merge_request.has_changes_requested?).to be_falsey }

    describe 'when merge request has changes requested' do
      before do
        create(:merge_request_requested_changes, merge_request: merge_request, project: merge_request.project, user: create(:user))
      end

      it { expect(merge_request.has_changes_requested?).to be_truthy }
    end
  end

  describe '#create_requested_changes' do
    let_it_be(:user) { create(:user) }

    it 'creates a merge request requested changes' do
      expect { merge_request.create_requested_changes(user) }.to change { merge_request.requested_changes.count }.from(0).to(1)
    end
  end

  describe '#destroy_requested_changes' do
    let_it_be(:user) { create(:user) }

    before do
      create(:merge_request_requested_changes, merge_request: merge_request, project: merge_request.project, user: user)
    end

    it 'destroys a merge request requested changes' do
      expect { merge_request.destroy_requested_changes(user) }.to change { merge_request.requested_changes.count }.from(1).to(0)
    end
  end

  describe '#ai_review_merge_request_allowed?' do
    let_it_be(:project) { create(:project) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
    let_it_be(:current_user) { create(:user, developer_of: project) }

    let(:authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }

    subject(:ai_review_merge_request_allowed?) { merge_request.ai_review_merge_request_allowed?(current_user) }

    before do
      stub_licensed_features(ai_review_mr: true)
      allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
    end

    context "when feature is authorized" do
      before do
        allow(authorizer).to receive(:allowed?).and_return(true)
      end

      it { is_expected.to eq(true) }

      context 'when ai_review_merge_request feature flag is disabled' do
        before do
          stub_feature_flags(ai_review_merge_request: false)
        end

        it { is_expected.to eq(false) }
      end

      context 'when license is not set' do
        before do
          stub_licensed_features(ai_review_mr: false)
        end

        it { is_expected.to eq(false) }
      end

      context 'when user cannot create note' do
        let(:current_user) { create(:user, guest_of: project) }

        it { is_expected.to eq(false) }
      end
    end

    context "when feature is not authorized" do
      before do
        allow(authorizer).to receive(:allowed?).and_return(false)
      end

      it { is_expected.to eq(false) }
    end
  end

  describe '#temporarily_unapproved?' do
    subject(:temporarily_unapproved) { merge_request.temporarily_unapproved? }

    let(:merge_request) { create(:merge_request) }

    context 'when the MR is not temporarily unapproved' do
      it 'returns false' do
        expect(temporarily_unapproved).to eq(false)
      end
    end

    context 'when the MR is temporarily unapproved' do
      before do
        merge_request.approval_state.temporarily_unapprove!
      end

      it 'returns true' do
        expect(temporarily_unapproved).to eq(true)
      end
    end
  end

  describe '#ai_reviewable_diff_files' do
    let(:merge_request) { build_stubbed(:merge_request) }
    let(:diff_file_a) { instance_double(Gitlab::Diff::File, ai_reviewable?: true) }
    let(:diff_file_b) { instance_double(Gitlab::Diff::File, ai_reviewable?: false) }
    let(:diff_file_c) { instance_double(Gitlab::Diff::File, ai_reviewable?: true) }
    let(:diff_files) { [diff_file_a, diff_file_b, diff_file_c] }
    let(:diffs) { instance_double(Gitlab::Diff::FileCollection::MergeRequestDiff, diff_files: diff_files) }

    before do
      allow(merge_request).to receive(:diffs).and_return(diffs)
    end

    it 'returns only AI reviewable diff files' do
      expect(merge_request.ai_reviewable_diff_files).to match_array([diff_file_a, diff_file_c])
    end
  end
end
