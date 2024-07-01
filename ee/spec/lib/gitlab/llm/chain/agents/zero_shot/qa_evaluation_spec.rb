# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GitLab Duo Chat QA Evaluation', :real_ai_request, :saas, :clean_gitlab_redis_chat, feature_category: :duo_chat do
  include Gitlab::Routing.url_helpers
  include DuoChatQaEvaluationHelpers
  include DuoChatFixtureHelpers

  let_it_be(:user) { create(:user) }

  # These fixtures have been created using https://gitlab.com/gitlab-org/gitlab/-/snippets/3613745
  let_it_be(:epic_fixtures) { load_fixture('epics') }
  let_it_be(:issue_fixtures) { load_fixture('issues') }

  before_all do
    stub_feature_flags(v2_chat_agent_integration: false)
    # link_reference_pattern is memoized for Issue
    # and stubbed url (gitlab.com) is not used to derive the link reference pattern.
    Issue.instance_variable_set(:@link_reference_pattern, nil)

    # Create epics and issues from the fixture data
    (epic_fixtures + issue_fixtures).each { |issuable| create_users(issuable) }
    epics = epic_fixtures.filter_map { |epic| restore_epic(epic) }
    issues = issue_fixtures.filter_map { |issue| restore_issue(issue) }

    [
      issues.map { |issue| issue.project.group.root_ancestor },
      epics.map { |epic| epic.group.root_ancestor }
    ].flatten.each do |group|
      group.namespace_settings.update_attribute(:experiment_features_enabled, true)
      group.add_owner(user)
    end

    issues.map(&:project).each { |project| project.add_developer(user) }
  end

  before do
    # Note: In SaaS simulation mode,
    # the url must be `https://gitlab.com` but the routing helper returns `localhost`
    # and breaks GitLab ReferenceExtractor
    stub_default_url_options(host: "gitlab.com", protocol: "https")
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(ai_chat: true, epics: true)
  end

  shared_examples 'the questions are correctly answered' do
    let(:test_cases) do
      question_templates.flat_map do |template|
        resource_ids.map do |resource_id|
          resource = resource_model.find(resource_id)

          {
            question: format(template, template_params.call(resource)),
            issuable: resource,
            context: resource.to_json
          }
        end
      end
    end

    it 'answers the questions correctly' do
      test_results = batch_evaluate

      test_results.each do |result|
        print_evaluation(result)

        result[:evaluations].each do |eval|
          grading = eval[:response]

          # Skip if no grade (CORRECT or INCORRECT) is present in the response.
          # (the LLM request failed for some reason or the LLM did not follow the instruction.)
          next unless grading.match(/Grade: CORRECT/i) || grading.match(/Grade: INCORRECT/i)

          expect(grading).to match(/Grade: CORRECT/i)
        end
      end
    end
  end

  # The following block is always run in the CI.
  # The purpose of this test is to detect a regression when there is an interface update.
  describe 'Fast QA evaluation', :fast_chat_qa_evaluation, :aggregate_failures do
    let(:resource_model) { Issue }
    let(:resource_ids) { [24652824] } # https://gitlab.com/gitlab-org/gitlab/-/issues/17800
    let(:template_params) { ->(_) { {} } }
    let(:question_templates) { ["Summarize this issue"] }

    it_behaves_like 'the questions are correctly answered'
  end

  context 'for issue questions', :chat_qa_evaluation, :aggregate_failures do
    let(:resource_model) { Issue }
    let(:template_params) { ->(issue) { { url: project_issue_url(issue.project, issue) } } }

    let(:resource_ids) do
      [
        24652824, # https://gitlab.com/gitlab-org/gitlab/-/issues/17800
        113414743, # https://gitlab.com/gitlab-org/gitlab/-/issues/371038
        128440335, # https://gitlab.com/gitlab-org/gitlab/-/issues/412831
        129393876, # https://gitlab.com/gitlab-org/gitlab/-/issues/415547
        130125924, # https://gitlab.com/gitlab-org/gitlab/-/issues/416800
        130193114 # https://gitlab.com/gitlab-com/www-gitlab-com/-/issues/34345
      ]
    end

    let(:question_templates) do
      [
        "what is this issue about?",
        "Summarize the comments into bullet points?",
        "Summarize with bullet points",
        "What are the unique use cases raised by commenters in this issue?",
        "Could you summarize this issue",
        "Summarize this Issue",
        "%<url>s - Summarize this issue",
        "What is the status of %<url>s?",
        "Please summarize the latest activity and current status of the issue %<url>s",
        "How can I improve the description of %<url>s " \
        "so that readers understand the value and problems to be solved?",
        "Please rewrite the description of %<url>s so that readers " \
        "understand the value and problems to be solved. " \
        "Also add common \"jobs to be done\" or use cases which should be considered from a usability perspective.",
        "Are there any open questions relating to this issue? %<url>s"
      ]
    end

    it_behaves_like 'the questions are correctly answered'
  end

  context 'for epic questions', :chat_qa_evaluation, :aggregate_failures do
    let(:resource_model) { Epic }
    let(:template_params) { ->(epic) { { url: group_epic_url(epic.group, epic) } } }

    let(:resource_ids) do
      [
        822061, # https://gitlab.com/groups/gitlab-org/-/epics/10550
        835460, # https://gitlab.com/groups/gitlab-org/-/epics/10694
        854759 # https://gitlab.com/groups/gitlab-org/-/epics/10814
      ]
    end

    let(:question_templates) do
      [
        "Summarize the comments into bullet points?",
        "Summarize with bullet points",
        "Can you create a simpler list of which questions a user should be able to ask according to this epic.",
        "How much work is left to be done %<url>s?",
        "How much work is left to be done in this epic?",
        "Please summarize what the objective and next steps are for %<url>s",
        "Summarize this Epic."
      ]
    end

    it_behaves_like 'the questions are correctly answered'
  end
end
