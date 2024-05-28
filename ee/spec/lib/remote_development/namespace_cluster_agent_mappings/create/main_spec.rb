# frozen_string_literal: true

require_relative '../../rd_fast_spec_helper'

RSpec.describe RemoteDevelopment::NamespaceClusterAgentMappings::Create::Main, :rd_fast, feature_category: :remote_development do
  let(:context_passed_along_steps) { {} }
  let(:rop_steps) do
    [
      [RemoteDevelopment::NamespaceClusterAgentMappings::Create::ClusterAgentValidator, :and_then],
      [RemoteDevelopment::NamespaceClusterAgentMappings::Create::MappingCreator, :and_then]
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
                  step_class: RemoteDevelopment::NamespaceClusterAgentMappings::Create::MappingCreator,
                  returned_message: RemoteDevelopment::Messages::NamespaceClusterAgentMappingCreateSuccessful.new(
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

    # rubocop:disable Style/TrailingCommaInArrayLiteral -- let the last element have a comma for simpler diffs
    # rubocop:disable Layout/LineLength -- we want to avoid excessive wrapping for RSpec::Parameterized Nested Array Style so we can have formatting consistency between entries
    where(:case_name, :err_result_for_step, :expected_response) do
      [
        [
          "when ClusterAgentValidator returns NamespaceClusterAgentMappingCreateValidationFailed",
          {
            step_class: RemoteDevelopment::NamespaceClusterAgentMappings::Create::ClusterAgentValidator,
            returned_message: lazy { RemoteDevelopment::Messages::NamespaceClusterAgentMappingCreateValidationFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Namespace cluster agent mapping create validation failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when MappingCreator returns NamespaceClusterAgentMappingCreateFailed",
          {
            step_class: RemoteDevelopment::NamespaceClusterAgentMappings::Create::MappingCreator,
            returned_message:
              lazy { RemoteDevelopment::Messages::NamespaceClusterAgentMappingCreateFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Namespace cluster agent mapping create failed: #{error_details}" },
            reason: :bad_request
          },
        ],

        [
          "when MappingCreator returns NamespaceClusterAgentMappingAlreadyExists",
          {
            step_class: RemoteDevelopment::NamespaceClusterAgentMappings::Create::MappingCreator,
            returned_message:
              lazy { RemoteDevelopment::Messages::NamespaceClusterAgentMappingAlreadyExists.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Namespace cluster agent mapping already exists: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when an unmatched error is returned, an exception is raised",
          {
            step_class: RemoteDevelopment::NamespaceClusterAgentMappings::Create::ClusterAgentValidator,
            returned_message: lazy { Class.new(RemoteDevelopment::Message).new(err_message_content) }
          },
          RemoteDevelopment::UnmatchedResultError,
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
