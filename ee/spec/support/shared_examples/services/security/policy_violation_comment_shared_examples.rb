# frozen_string_literal: true

RSpec.shared_examples_for 'triggers policy bot comment' do |report_type, expected_violation,
  requires_approval: true|
  it 'enqueues Security::GeneratePolicyViolationCommentWorker' do
    expect(Security::GeneratePolicyViolationCommentWorker).to receive(:perform_async).with(
      merge_request.id,
      { 'report_type' => Security::ScanResultPolicies::PolicyViolationComment::REPORT_TYPES[report_type],
        'violated_policy' => expected_violation,
        'requires_approval' => requires_approval }
    )

    execute
  end

  if expected_violation
    context 'when bot comment is disabled' do
      context 'when it is disabled for all policies' do
        before do
          merge_request.project.scan_result_policy_reads.update_all(send_bot_message: { enabled: false })
        end

        it_behaves_like 'does not trigger policy bot comment'

        context 'when feature flag approval_policy_disable_bot_comment is disabled' do
          before do
            stub_feature_flags(
              approval_policy_disable_bot_comment: false,
              approval_policy_disable_bot_comment_group: false
            )
          end

          it 'enqueues Security::GeneratePolicyViolationCommentWorker' do
            expect(Security::GeneratePolicyViolationCommentWorker).to receive(:perform_async).with(
              merge_request.id,
              { 'report_type' => Security::ScanResultPolicies::PolicyViolationComment::REPORT_TYPES[report_type],
                'violated_policy' => expected_violation,
                'requires_approval' => requires_approval }
            )

            execute
          end
        end
      end

      context 'when it is disabled only for one policy' do
        before do
          policy = create(:scan_result_policy_read, :with_send_bot_message, project: merge_request.project,
            bot_message_enabled: false)
          create(:report_approver_rule, :scan_finding, merge_request: merge_request, scan_result_policy_read: policy,
            name: 'Rule with disabled policy bot comment')
        end

        it 'enqueues Security::GeneratePolicyViolationCommentWorker' do
          expect(Security::GeneratePolicyViolationCommentWorker).to receive(:perform_async).with(
            merge_request.id,
            { 'report_type' => Security::ScanResultPolicies::PolicyViolationComment::REPORT_TYPES[report_type],
              'violated_policy' => expected_violation,
              'requires_approval' => requires_approval }
          )

          execute
        end
      end
    end
  end
end

RSpec.shared_examples_for "does not trigger policy bot comment" do
  it 'does not trigger policy bot comment' do
    expect(Security::GeneratePolicyViolationCommentWorker).not_to receive(:perform_async)

    execute
  end
end
