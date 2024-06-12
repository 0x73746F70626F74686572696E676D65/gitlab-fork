# frozen_string_literal: true

require_relative '../../rd_fast_spec_helper'

RSpec.describe RemoteDevelopment::Workspaces::Update::Main, :rd_fast, feature_category: :remote_development do
  let(:context_passed_along_steps) { {} }

  let(:rop_steps) do
    [
      [RemoteDevelopment::Workspaces::Update::Authorizer, :and_then],
      [RemoteDevelopment::Workspaces::Update::Updater, :and_then]
    ]
  end

  describe "happy path" do
    let(:ok_message_content) { { ok_details: "Everything is OK!" } }
    let(:expected_response) do
      {
        status: :success,
        payload: ok_message_content
      }
    end

    it "returns expected response" do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect do
        described_class.main(context_passed_along_steps)
      end
        .to invoke_rop_steps(rop_steps)
              .from_main_class(described_class)
              .with_context_passed_along_steps(context_passed_along_steps)
              .with_ok_result_for_step(
                {
                  step_class: RemoteDevelopment::Workspaces::Update::Updater,
                  returned_message: RemoteDevelopment::Messages::WorkspaceUpdateSuccessful.new(
                    ok_message_content
                  )
                }
              )
              .and_return_expected_value(expected_response)
    end
  end

  describe "error cases" do
    let(:error_details) { "some error details" }
    let(:err_message_content) { { details: error_details } }

    shared_examples "rop invocation with error response" do
      it "returns expected response" do
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect do
          described_class.main(context_passed_along_steps)
        end
          .to invoke_rop_steps(rop_steps)
                .from_main_class(described_class)
                .with_context_passed_along_steps(context_passed_along_steps)
                .with_err_result_for_step(err_result_for_step)
                .and_return_expected_value(expected_response)
      end
    end

    where(:case_name, :err_result_for_step, :expected_response) do
      [
        [
          "when Authorizer returns Unauthorized",
          {
            step_class: RemoteDevelopment::Workspaces::Update::Authorizer,
            returned_message: lazy { RemoteDevelopment::Messages::Unauthorized.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Unauthorized: #{error_details}" },
            reason: :unauthorized
          }
        ],
        [
          "when Updater returns WorkspaceUpdateFailed",
          {
            step_class: RemoteDevelopment::Workspaces::Update::Updater,
            returned_message: lazy { RemoteDevelopment::Messages::WorkspaceUpdateFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Workspace update failed: #{error_details}" },
            reason: :bad_request
          }
        ],
        [
          "when an unmatched error is returned, an exception is raised",
          {
            step_class: RemoteDevelopment::Workspaces::Update::Authorizer,
            returned_message: lazy { Class.new(RemoteDevelopment::Message).new(err_message_content) }
          },
          RemoteDevelopment::UnmatchedResultError
        ]

      ]
    end

    with_them do
      it_behaves_like "rop invocation with error response"
    end
  end
end
