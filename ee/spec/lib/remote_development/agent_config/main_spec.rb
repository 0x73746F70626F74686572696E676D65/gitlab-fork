# frozen_string_literal: true

require_relative '../rd_fast_spec_helper'

RSpec.describe RemoteDevelopment::AgentConfig::Main, :rd_fast, feature_category: :remote_development do # rubocop:disable RSpec/EmptyExampleGroup -- the context blocks are dynamically generated
  let(:context_passed_along_steps) { {} }

  let(:rop_steps) do
    [
      [RemoteDevelopment::AgentConfig::LicenseChecker, :and_then],
      [RemoteDevelopment::AgentConfig::Updater, :and_then]
    ]
  end

  describe "happy path" do
    let(:ok_message_content) { { ok_details: "Everything is OK!" } }
    let(:skipped_message_content) { { skipped_reason: :skipped } }

    shared_examples "rop invocation with successful response" do
      it "returns expected response" do
        # noinspection RubyResolve -- TODO: open issue and add to https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues
        expect do
          described_class.main(context_passed_along_steps)
        end
          .to invoke_rop_steps(rop_steps)
                .from_main_class(described_class)
                .with_context_passed_along_steps(context_passed_along_steps)
                .with_ok_result_for_step(result_for_step)
                .and_return_expected_value(expected_response)
      end
    end

    # rubocop:disable Style/TrailingCommaInArrayLiteral -- let the last element have a comma for simpler diffs
    # rubocop:disable Layout/LineLength -- we want to avoid excessive wrapping for RSpec::Parameterized Nested Array Style so we can have formatting consistency between entries
    where(:case_name, :result_for_step, :expected_response) do
      [
        [
          "when Updater returns AgentConfigUpdateSuccessful",
          {
            step_class: RemoteDevelopment::AgentConfig::Updater,
            returned_message: lazy { RemoteDevelopment::Messages::AgentConfigUpdateSuccessful.new(ok_message_content) }
          },
          {
            status: :success,
            payload: lazy { ok_message_content }
          },
        ],
        [
          "when Updater returns AgentConfigUpdateSkippedBecauseNoConfigFileEntryFound",
          {
            step_class: RemoteDevelopment::AgentConfig::Updater,
            returned_message: lazy { RemoteDevelopment::Messages::AgentConfigUpdateSkippedBecauseNoConfigFileEntryFound.new(skipped_message_content) }
          },
          {
            status: :success,
            payload: lazy { skipped_message_content }
          }
        ]
      ]
    end
    with_them do
      it_behaves_like "rop invocation with successful response"
    end
  end

  describe "error cases" do
    let(:error_details) { "some error details" }
    let(:err_message_content) { { details: error_details } }

    shared_examples "rop invocation with error response" do
      it "returns expected response" do
        # noinspection RubyResolve -- TODO: open issue and add to https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues
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
          "when LicenseChecker returns LicenseCheckFailed",
          {
            step_class: RemoteDevelopment::AgentConfig::LicenseChecker,
            returned_message: lazy { RemoteDevelopment::Messages::LicenseCheckFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "License check failed: #{error_details}" },
            reason: :forbidden
          },
        ],
        [
          "when Updater returns AgentConfigUpdateFailed",
          {
            step_class: RemoteDevelopment::AgentConfig::Updater,
            returned_message: lazy { RemoteDevelopment::Messages::AgentConfigUpdateFailed.new(err_message_content) }
          },
          {
            status: :error,
            message: lazy { "Agent config update failed: #{error_details}" },
            reason: :bad_request
          },
        ],
        [
          "when an unmatched error is returned, an exception is raised",
          {
            step_class: RemoteDevelopment::NamespaceClusterAgentMappings::Delete::MappingDeleter,
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
