# frozen_string_literal: true

require_relative '../../rd_fast_spec_helper'

RSpec.describe RemoteDevelopment::Workspaces::Reconcile::Main, :rd_fast, feature_category: :remote_development do
  let(:context_passed_along_steps) { {} }
  let(:response_payload) do
    {
      workspace_rails_infos: [],
      settings: { settings: 'some_Settings' }
    }
  end

  let(:rop_steps) do
    [
      [RemoteDevelopment::Workspaces::Reconcile::Input::ParamsValidator, :and_then],
      [RemoteDevelopment::Workspaces::Reconcile::Input::ParamsExtractor, :map],
      [RemoteDevelopment::Workspaces::Reconcile::Input::ParamsToInfosConverter, :map],
      [RemoteDevelopment::Workspaces::Reconcile::Input::AgentInfosObserver, :map],
      [RemoteDevelopment::Workspaces::Reconcile::Persistence::WorkspacesFromAgentInfosUpdater, :map],
      [RemoteDevelopment::Workspaces::Reconcile::Persistence::OrphanedWorkspacesObserver, :map],
      [RemoteDevelopment::Workspaces::Reconcile::Persistence::WorkspacesToBeReturnedFinder, :map],
      [RemoteDevelopment::Workspaces::Reconcile::Output::ResponsePayloadBuilder, :map],
      [RemoteDevelopment::Workspaces::Reconcile::Persistence::WorkspacesToBeReturnedUpdater, :map],
      [RemoteDevelopment::Workspaces::Reconcile::Output::ResponsePayloadObserver, :map]
    ]
  end

  describe "happy path" do
    let(:context_passed_along_steps) do
      {
        ok_details: "Everything is OK!",
        response_payload: response_payload
      }
    end

    let(:expected_response) do
      {
        status: :success,
        payload: response_payload
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

    # rubocop:disable Style/TrailingCommaInArrayLiteral -- let the last element have a comma for simpler diffs
    # rubocop:disable Layout/LineLength -- we want to avoid excessive wrapping for RSpec::Parameterized Nested Array Style so we can have formatting consistency between entries
    where(:case_name, :err_result_for_step, :expected_response) do
      [
        [
          "when ParamsValidator returns WorkspaceReconcileParamsValidationFailed",
          {
            step_class: RemoteDevelopment::Workspaces::Reconcile::Input::ParamsValidator,
            returned_message: lazy { RemoteDevelopment::Messages::WorkspaceReconcileParamsValidationFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Workspace reconcile params validation failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when an unmatched error is returned, an exception is raised",
          {
            step_class: RemoteDevelopment::Workspaces::Reconcile::Input::ParamsValidator,
            returned_message: lazy { Class.new(RemoteDevelopment::Message).new(err_message_content) }
          },
          RemoteDevelopment::UnmatchedResultError
        ]
      ]
    end
    # rubocop:enable Style/TrailingCommaInArrayLiteral
    # rubocop:enable Layout/LineLength

    with_them do
      it_behaves_like "rop invocation with error response"
    end
  end
end
