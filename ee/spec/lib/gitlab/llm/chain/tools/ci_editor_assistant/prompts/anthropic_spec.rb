# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::CiEditorAssistant::Prompts::Anthropic, feature_category: :pipeline_composition do
  describe '.prompt' do
    let_it_be(:user) { create(:user) }
    let(:options) do
      {
        input: "foo"
      }
    end

    let(:context) do
      Gitlab::Llm::Chain::GitlabContext.new(
        current_user: user,
        container: nil,
        resource: nil,
        ai_request: nil
      )
    end

    it 'returns prompt in correct format for messages api' do
      prompt = described_class.prompt(options)[:prompt]
      expect(prompt.length).to eq(3)

      expect(prompt[0][:role]).to eq(:system)
      expect(prompt[0][:content]).to eq(system_prompt)

      expect(prompt[1][:role]).to eq(:user)
      expect(prompt[1][:content]).to eq("foo")

      expect(prompt[2][:role]).to eq(:assistant)
      expect(prompt[2][:content]).to eq('```yaml')
    end
  end

  def system_prompt
    <<~PROMPT
          You are an ai assistant talking to a devops or software engineer.
          You should coach users to author a ".gitlab-ci.yml" file which can be used to create a GitLab pipeline.
          Please provide concrete and detailed yaml that implements what the user asks for as closely as possible, assuming a single yaml file will be used.

          Think step by step to provide the most accurate solution to the user problem. Make sure that all the stages you've defined in the yaml file are actually used in it.
          If you realise you require more input from the user, please describe what information is missing and ask them to provide it. Specifically check, if you have information about the application you're providing a configuration for, for example, the programming language used, or deployment targets.
          If any configuration is missing, such as configuration variables, connection strings, secrets and so on, assume it will be taken from GitLab Ci/CD variables. Please include the variables configuration block that would use these Ci/CD variables.

          Please include the commented sections explaining every configuration block, unless the user explicitly asks you to skip or not include comments.
    PROMPT
  end
end
