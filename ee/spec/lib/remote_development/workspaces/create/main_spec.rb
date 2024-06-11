# frozen_string_literal: true

require_relative "../../rd_fast_spec_helper"

RSpec.describe RemoteDevelopment::Workspaces::Create::Main, :rd_fast, feature_category: :remote_development do
  let(:context_passed_along_steps) { {} }
  let(:rop_steps) do
    [
      [RemoteDevelopment::Workspaces::Create::Authorizer, :and_then],
      [RemoteDevelopment::Workspaces::Create::DevfileFetcher, :and_then],
      [RemoteDevelopment::Workspaces::Create::PreFlattenDevfileValidator, :and_then],
      [RemoteDevelopment::Workspaces::Create::DevfileFlattener, :and_then],
      [RemoteDevelopment::Workspaces::Create::PostFlattenDevfileValidator, :and_then],
      [RemoteDevelopment::Workspaces::Create::VolumeDefiner, :map],
      [RemoteDevelopment::Workspaces::Create::ToolsComponentInjector, :map],
      [RemoteDevelopment::Workspaces::Create::ProjectClonerComponentInjector, :map],
      [RemoteDevelopment::Workspaces::Create::VolumeComponentInjector, :map],
      [RemoteDevelopment::Workspaces::Create::Creator, :and_then]
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
                  step_class: RemoteDevelopment::Workspaces::Create::Creator,
                  returned_message: RemoteDevelopment::Messages::WorkspaceCreateSuccessful.new(ok_message_content)
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

    # rubocop:disable Style/TrailingCommaInArrayLiteral -- let the last element have a comma for simpler diffs
    # rubocop:disable Layout/LineLength -- we want to avoid excessive wrapping for RSpec::Parameterized Nested Array Style so we can have formatting consistency between entries
    where(:case_name, :err_result_for_step, :expected_response) do
      [
        [
          "when Authorizer returns Unauthorized",
          {
            step_class: RemoteDevelopment::Workspaces::Create::Authorizer,
            returned_message: lazy { RemoteDevelopment::Messages::Unauthorized.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Unauthorized: #{error_details}" },
            reason: :unauthorized
          },
        ],
        [
          "when DevfileFetcher returns WorkspaceCreateParamsValidationFailed",
          {
            step_class: RemoteDevelopment::Workspaces::Create::DevfileFetcher,
            returned_message:
              lazy { RemoteDevelopment::Messages::WorkspaceCreateParamsValidationFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Workspace create params validation failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when DevfileFetcher returns WorkspaceCreateDevfileLoadFailed",
          {
            step_class: RemoteDevelopment::Workspaces::Create::DevfileFetcher,
            returned_message: lazy { RemoteDevelopment::Messages::WorkspaceCreateDevfileLoadFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Workspace create devfile load failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when DevfileFetcher returns WorkspaceCreateDevfileYamlParseFailed",
          {
            step_class: RemoteDevelopment::Workspaces::Create::DevfileFetcher,
            returned_message: lazy { RemoteDevelopment::Messages::WorkspaceCreateDevfileYamlParseFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Workspace create devfile yaml parse failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when PreFlattenDevfileValidator returns WorkspaceCreatePreFlattenDevfileValidationFailed",
          {
            step_class: RemoteDevelopment::Workspaces::Create::PreFlattenDevfileValidator,
            returned_message: lazy { RemoteDevelopment::Messages::WorkspaceCreatePreFlattenDevfileValidationFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Workspace create pre flatten devfile validation failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when DevfileFlattener returns WorkspaceCreatePreFlattenDevfileValidationFailed",
          {
            step_class: RemoteDevelopment::Workspaces::Create::DevfileFlattener,
            returned_message: lazy { RemoteDevelopment::Messages::WorkspaceCreateDevfileFlattenFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Workspace create devfile flatten failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when PostFlattenDevfileValidator returns WorkspaceCreatePostFlattenDevfileValidationFailed",
          {
            step_class: RemoteDevelopment::Workspaces::Create::PostFlattenDevfileValidator,
            returned_message: lazy { RemoteDevelopment::Messages::WorkspaceCreatePostFlattenDevfileValidationFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Workspace create post flatten devfile validation failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when Creator returns WorkspaceCreateFailed",
          {
            step_class: RemoteDevelopment::Workspaces::Create::Creator,
            returned_message: lazy { RemoteDevelopment::Messages::WorkspaceCreateFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Workspace create failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when an unmatched error is returned, an exception is raised",
          {
            step_class: RemoteDevelopment::Workspaces::Create::Creator,
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
