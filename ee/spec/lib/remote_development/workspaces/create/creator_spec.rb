# frozen_string_literal: true

require 'spec_helper'

# frozen_string_literal: true
# rubocop:disable Rails/SaveBang -- method shadowing

Messages = RemoteDevelopment::Messages
RSpec.describe ::RemoteDevelopment::Workspaces::Create::Creator, feature_category: :remote_development do # rubocop:disable RSpec/EmptyExampleGroup -- the context blocks are dynamically generated
  let(:rop_steps) do
    [
      [RemoteDevelopment::Workspaces::Create::PersonalAccessTokenCreator, :and_then],
      [RemoteDevelopment::Workspaces::Create::WorkspaceCreator, :and_then],
      [RemoteDevelopment::Workspaces::Create::WorkspaceVariablesCreator, :and_then]
    ]
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:agent) { create(:ee_cluster_agent, :with_remote_development_agent_config) }
  let(:random_string) { 'abcdef' }

  let(:params) do
    {
      agent: agent
    }
  end

  let(:initial_value) do
    {
      params: params,
      current_user: user
    }
  end

  let(:workspace) { instance_double("RemoteDevelopment::Workspace") }

  let(:updated_value) do
    initial_value.merge(
      {
        workspace_name: "workspace-#{agent.id}-#{user.id}-#{random_string}",
        workspace_namespace: "gl-rd-ns-#{agent.id}-#{user.id}-#{random_string}"
      }
    )
  end

  before do
    allow(SecureRandom).to receive(:alphanumeric) { random_string }
  end

  describe "happy path" do
    let(:expected_response) do
      Result.ok(RemoteDevelopment::Messages::WorkspaceCreateSuccessful.new(updated_value))
    end

    it "returns expected response" do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect do
        described_class.create(initial_value)
      end
        .to invoke_rop_steps(rop_steps)
              .from_main_class(described_class)
              .with_value_passed_along_steps(updated_value)
              .and_return_expected_value(expected_response)
    end
  end

  describe "error cases" do
    let(:error_details) { "some error details" }
    let(:err_message_content) { { errors: error_details } }

    shared_examples "rop invocation with error response" do
      it "returns expected response" do
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect do
          described_class.create(initial_value)
        end
          .to invoke_rop_steps(rop_steps)
                .from_main_class(described_class)
                .with_value_passed_along_steps(updated_value)
                .with_err_result_for_step(err_result_for_step)
                .and_return_expected_value(expected_response)
      end
    end

    # rubocop:disable Style/TrailingCommaInArrayLiteral -- let the last element have a comma for simpler diffs
    # rubocop:disable Layout/LineLength -- we want to avoid excessive wrapping for RSpec::Parameterized Nested Array Style so we can have formatting consistency between entries
    where(:case_name, :err_result_for_step, :expected_response) do
      [
        [
          "when PersonalAccessTokenCreator returns PersonalAccessTokenModelCreateFailed",
          {
            step_class: RemoteDevelopment::Workspaces::Create::PersonalAccessTokenCreator,
            returned_message: lazy { Messages::PersonalAccessTokenModelCreateFailed.new(err_message_content) }
          },
          lazy { Result.err(Messages::WorkspaceCreateFailed.new(err_message_content)) }
        ],
        [
          "when WorkspaceCreator returns WorkspaceModelCreateFailed",
          {
            step_class: RemoteDevelopment::Workspaces::Create::WorkspaceCreator,
            returned_message: lazy { Messages::WorkspaceModelCreateFailed.new(err_message_content) }
          },
          lazy { Result.err(Messages::WorkspaceCreateFailed.new(err_message_content)) }
        ],
        [
          "when WorkspaceVariablesCreator returns WorkspaceVariablesModelCreateFailed",
          {
            step_class: RemoteDevelopment::Workspaces::Create::WorkspaceVariablesCreator,
            returned_message: lazy { Messages::WorkspaceVariablesModelCreateFailed.new(err_message_content) }
          },
          lazy { Result.err(Messages::WorkspaceCreateFailed.new(err_message_content)) }
        ]
      ]
    end
    # rubocop:enable Style/TrailingCommaInArrayLiteral
    # rubocop:enable Layout/LineLength
    # rubocop:enable Rails/SaveBang
    with_them do
      it_behaves_like "rop invocation with error response"
    end
  end
end
