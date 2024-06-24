# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Completions::Chat, :clean_gitlab_redis_chat, feature_category: :duo_chat do
  include FakeBlobHelpers

  let_it_be(:user) { create(:user) }

  describe 'real requests', :real_ai_request, :zeroshot_executor, :saas do
    using RSpec::Parameterized::TableSyntax

    let_it_be_with_reload(:group) { create(:group_with_plan, :public, plan: :premium_plan) }
    let_it_be(:project) { create(:project, :repository, group: group) }

    let(:response_service_double) { instance_double(::Gitlab::Llm::ResponseService) }
    let(:resource) { nil }
    let(:extra_resource) { {} }
    let(:current_file) { nil }
    let(:options) do
      { extra_resource: extra_resource, current_file: current_file }
    end

    let(:executor) do
      message = ::Gitlab::Llm::ChatMessage.new(
        'user' => user,
        'content' => input,
        'role' => 'user',
        'context' => build(:ai_chat_message, user: user, content: input, resource: resource)
      )

      described_class.new(message, ::Gitlab::Llm::Completions::Chat, options)
    end

    before_all do
      group.add_owner(user)
    end

    before do
      stub_licensed_features(ai_chat: true, epics: true)

      stub_ee_application_setting(should_check_namespace_plan: true)
      group.namespace_settings.update!(experiment_features_enabled: true)
      allow(response_service_double).to receive(:execute).at_least(:once)
    end

    shared_examples_for 'successful prompt processing' do
      it 'answers query using expected tools', :aggregate_failures do
        # make the call to Duo Chat in order to receive the list of selected tools
        executor.execute
        expect(executor.context).to match_llm_tools(tools)
      end
    end

    context 'with blob as resource' do
      let(:blob) { project.repository.blob_at("master", "files/ruby/popen.rb") }
      let(:extra_resource) { { blob: blob } }

      where(:input_template, :tools) do
        'Explain the code'          | []
        'Explain this code'         | []
        'What is this code doing?'  | []
        'Can you explain the code ""def hello_world\\nputs(\""Hello, world!\\n\"");\nend""?' | []
      end

      with_them do
        let(:input) { input_template }

        it_behaves_like 'successful prompt processing'
      end

      context 'with blob for code containing gitlab references' do
        let(:blob) do
          fixture = File.read('ee/spec/fixtures/llm/projects_controller.rb')

          fake_blob(path: 'app/controllers/explore/projects_controller.rb', data: fixture)
        end

        let(:input) { 'What is this code doing?' }
        let(:tools) { [] }

        it_behaves_like 'successful prompt processing'
      end
    end

    context 'without tool' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

      where(:input_template, :tools) do
        'Summarize this Merge Request' | []
        'Summarize %<merge_request_identifier>s Merge Request' | []
        'Why did this pipeline fail?' | []
      end

      with_them do
        let(:resource) { merge_request }
        let(:input) { format(input_template, merge_request_identifier: merge_request.to_reference(full: true).to_s) }

        it_behaves_like 'successful prompt processing'
      end
    end

    context 'with predefined issue', time_travel_to: Time.utc(2023, 8, 11) do
      let_it_be(:due_date) { 3.days.from_now }
      let_it_be(:label) { create(:label, project: project, title: 'ai-enablement') }
      let_it_be(:milestone) { create(:milestone, project: project, title: 'milestone1', due_date: due_date) }
      let_it_be(:issue) do
        create(:issue, project: project, title: 'A testing issue for AI reliability',
          description: 'This issue is about evaluating reliability of various AI providers.',
          labels: [label], created_at: 2.days.ago, milestone: milestone)
      end

      let_it_be(:comment) do
        create(:note_on_issue, author: user, project: project, noteable: issue,
          note: 'I believe that latency is an important measure of reliability')
      end

      context 'with predefined tools' do
        context 'with issue reference' do
          let(:input) { format(input_template, issue_identifier: "the issue #{issue.to_reference(full: true)}") }

          # rubocop: disable Layout/LineLength -- keep table structure readable
          where(:input_template, :tools) do
            'Please summarize %<issue_identifier>s' | %w[IssueReader]
            'Summarize %<issue_identifier>s with bullet points' | %w[IssueReader]
            'Can you list all the labels on %<issue_identifier>s?' | %w[IssueReader]
            'How old is %<issue_identifier>s?' | %w[IssueReader]
            'How many days ago %<issue_identifier>s was created?' | %w[IssueReader]
            'For which milestone is %<issue_identifier>s? And how long until then' | %w[IssueReader]
            'Summarize the comments from %<issue_identifier>s into bullet points' | %w[IssueReader]
            'What should be the final solution for %<issue_identifier>s?' | %w[IssueReader]
          end
          # rubocop: enable Layout/LineLength

          with_them do
            it_behaves_like 'successful prompt processing'
          end
        end

        context 'with `this issue`, direct answer using current resource' do
          let(:resource) { issue }
          let(:input) { format(input_template, issue_identifier: "this issue") }

          # rubocop: disable Layout/LineLength -- keep table structure readable
          where(:input_template, :tools) do
            'Please summarize %<issue_identifier>s' | %w[]
            'Can you list all the labels on %<issue_identifier>s?' | %w[]
            'How old is %<issue_identifier>s?' | %w[]
            'How many days ago %<issue_identifier>s was created?' | %w[]
            'For which milestone is %<issue_identifier>s? And how long until then' | %w[]
            'What should be the final solution for %<issue_identifier>s?' | %w[]
          end
          # rubocop: enable Layout/LineLength

          with_them do
            it_behaves_like 'successful prompt processing'
          end
        end
      end

      context 'with chat history' do
        let(:history) do
          [
            { role: 'user', content: "What is issue #{issue.to_reference(full: true)} about?" },
            {
              role: 'assistant', content: "The summary of issue is:\n\n## Provider Comparison\n" \
                                          "- Difficulty in evaluating which provider is better \n" \
                                          "- Both providers have pros and cons"
            }
          ]
        end

        before do
          uuid = SecureRandom.uuid

          history.each do |message|
            create(:ai_chat_message, message.merge(request_id: uuid, user: user))
          end

          create(:note_on_issue, author: user, project: project, noteable: issue,
            note: 'I would like a provider that is good at writing unit tests')
          create(:note_on_issue, author: user, project: project, noteable: issue,
            note: 'My company would use this to write test for our code')
          create(:note_on_issue, author: user, project: project, noteable: issue,
            note: 'We are interested in using this for project management')
          create(:note_on_issue, author: user, project: project, noteable: issue,
            note: 'I would suggest a provider that handles creating issue summaries, which is what we\'ll use it for')
          create(:note_on_issue, author: user, project: project, noteable: issue,
            note: '+1, our company will also use this to manage our projects!')
        end

        # rubocop: disable Layout/LineLength -- keep table structure readable
        where(:input_template, :tools) do
          # evaluation of questions which involve processing of other resources is not reliable yet
          # because the IssueReader tool assumes we work with single resource:
          # IssueReader overrides context.resource
          'Can you provide more details about that issue?' | %w[IssueReader]
          'Can you reword your answer?' | []
          'Can you simplify your answer?' | []
          'Can you expand on your last paragraph?' | []
          'Can you identify the unique use cases the commenters have raised on this issue?' | %w[IssueReader]
        end
        # rubocop: enable Layout/LineLength

        with_them do
          let(:input) { format(input_template) }

          it_behaves_like 'successful prompt processing'
        end

        context 'with additional history' do
          let(:history) do
            [
              { role: 'user', content: "What is issue #{issue.to_reference(full: true)} about?" },
              {
                role: 'assistant', content: "The summary of issue is:\n\n## Provider Comparison\n" \
                                            "- Difficulty in evaluating which provider is better \n" \
                                            "- Both providers have pros and cons"
              },
              {
                role: 'user', content: "Can you identify the unique use cases the commenters have raised on this issue?"
              },
              {
                role: 'assistant', content: "Based on the issue comments, some of the unique use cases raised are:\n" \
                                            "- Writing unit tests\n- Project management \n" \
                                            "- Creating issue summaries\n- Low latency/high reliability"
              }
            ]
          end

          # rubocop: disable Layout/LineLength -- keep table structure readable
          where(:input_template, :tools) do
            'Can you sort this list by the number of users that have requested the use case and include the number for each use case? Can you include a verbatim for the two most requested use cases that reflect the general opinion of commenters for these two use cases?' | %w[]
          end
          # rubocop: enable Layout/LineLength

          with_them do
            let(:input) { format(input_template) }

            it_behaves_like 'successful prompt processing'
          end
        end
      end
    end

    context 'when asking to explain code' do
      # rubocop: disable Layout/LineLength -- keep table structure readable
      where(:input_template, :tools) do
        # NOTE: `tools: []` is the correct expected value.
        # There is no tool for explaining a code and the LLM answers the question directly.
        'Can you explain the code ""def hello_world\\nputs(\""Hello, world!\\n\"");\nend""?' | []
        'Can you explain function ""def hello_world\\nputs(\""Hello, world!\\n\"");\nend""?' | []
        'Write me tests for function ""def hello_world\\nputs(\""Hello, world!\\n\"");\nend""' | []
        'What is the complexity of the function ""def hello_world\\nputs(\""Hello, world!\\n\"");\nend""?' | []
        'How would you refactor the ""def hello_world\\nputs(\""Hello, world!\\n\"");\nend"" code?' | []
        'Can you fix the bug in my ""def hello_world\\nput(\""Hello, world!\\n\"");\nend"" code?' | []
        'Create an example of how to use method ""def hello_world\\nput(\""Hello, world!\\n\"");\nend""' | []
        'Write documentation for ""def hello_world\\nputs(\""Hello, world!\\n\"");\nend""?' | []
        'Create a function to validate an e-mail address' | []
        'Create a function in Python to call the spotify API to get my playlists' | []
        'Create a tic tac toe game in Javascript' | []
        'What would the ""def hello_world\\nputs(\""Hello, world!\\n\"");\nend"" code look like in Python?' | []
      end
      # rubocop: enable Layout/LineLength

      with_them do
        let(:input) { input_template }

        it_behaves_like 'successful prompt processing'
      end
    end

    context 'when asking about how to use GitLab' do
      where(:input_template, :tools) do
        'How do I change my password in GitLab' | ['GitlabDocumentation']
        'How do I fork a project?' | ['GitlabDocumentation']
        'How do I clone a repository?' | ['GitlabDocumentation']
        'How do I create a project template?' | ['GitlabDocumentation']
        'What is DevOps? What is DevSecOps?' | ['GitlabDocumentation']
        'Is it possible to resolve threads in issues?' | ['GitlabDocumentation']
        'Can I use you to search for code on GitLab?' | []
        'How can I search for code on Gitlab' | ['GitlabDocumentation']
        'Is it possible to add stages to pipelines?' | ['GitlabDocumentation']
        'Explain the GitLab Flow Branching Strategy' | ['GitlabDocumentation']
        'How to standardize CICD using GitLab?' | ['GitlabDocumentation']
        'Can I fetch a job by name using the Gitlab API?' | ['GitlabDocumentation']
        'How does remote development feature work?' | ['GitlabDocumentation']
        'How can I migrate from Jenkins to GitLab CI/CD?' | ['GitlabDocumentation']
        'How do I push an existing folder into a newly created GitLab Repository?' | ['GitlabDocumentation']
        'How do I run unit tests for my Next JS application in a GitLab pipeline?' | ['GitlabDocumentation']
        'How to clone a github project to gitlab and keep both repositories in sync?' | ['GitlabDocumentation']
        'What is the maximum artifact upload limit?' | ['GitlabDocumentation']
        'What is the artifact upload limit for self-managed?' | ['GitlabDocumentation']
        'What is the job maximum artifact size?' | ['GitlabDocumentation']
        'What is the recommended installation for GitLab?' | ['GitlabDocumentation']
        'How can I achieve high availability with GitLab?' | ['GitlabDocumentation']
        'What are the tradeoffs between GitLab SaaS vs GitLab self-managed?' | ['GitlabDocumentation']
        'How do I create a secure connection from a ci job to AWS?' | ['GitlabDocumentation']
        'What are security policies?' | ['GitlabDocumentation']
        'How do I set up gitlba pages' | ['GitlabDocumentation']
        'How do I set up SAML for my GitLab Instance' | ['GitlabDocumentation']
        'What is the difference between gitlab ultimate and gitlab premium?' | ['GitlabDocumentation']
        'how do i create custom rulesets with the secret detection scanner?' | ['GitlabDocumentation']
        'Is the 50,000 compute units that come with Ultimate for the entire namespace or per user?' \
        | ['GitlabDocumentation']
        'Where is GitLab.com hosted in GCP?' | ['GitlabDocumentation']
        'Is it possible to link MRs between two projects?' | ['GitlabDocumentation']
        'What can you do with AI?' | []
        'What are the key differences between GitHub Actions and GitLab CI/CD?' | ['GitlabDocumentation']
        'Can I store Ruby Gems in the package registry? What are the limitations?' | ['GitlabDocumentation']
        'where can i find documentation for Azure SAML SSO?' | ['GitlabDocumentation']
        'What are artifacts in gitlab?' | ['GitlabDocumentation']
        'What kinds of things can you help with?' | []
        'Can I proxy to Maven Central using the Maven package regsitry?' | ['GitlabDocumentation']
        'Can you help me setup a gitlab pages site?' | ['GitlabDocumentation']
      end

      with_them do
        let(:input) { input_template }

        before do
          allow_next_instance_of(Gitlab::Llm::Chain::Tools::GitlabDocumentation::Executor) do |instance|
            allow(instance).to receive(:perform).and_return(
              Gitlab::Llm::Chain::Answer.final_answer(context: instance.context, content: 'foo')
            )
          end
        end

        it_behaves_like 'successful prompt processing'
      end
    end

    context 'with predefined epic' do
      let_it_be(:label) { create(:group_label, group: group, title: 'ai-framework') }
      let_it_be(:epic) do
        create(:epic, group: group, title: 'A testing epic for AI reliability',
          description: 'This epic is about evaluating reliability of different AI prompts in chat',
          labels: [label], created_at: 5.days.ago)
      end

      before do
        stub_licensed_features(ai_chat: true, epics: true)
      end

      context 'with predefined tools' do
        context 'with epic reference' do
          let(:input) { format(input_template, epic_identifier: "the epic #{epic.to_reference(full: true)}") }

          # rubocop: disable Layout/LineLength -- keep table structure readable
          where(:input_template, :tools) do
            'Please summarize %<epic_identifier>s'                    | %w[EpicReader]
            'Can you list all labels on %{epic_identifier} epic?'     | %w[EpicReader]
            'How old is %<epic_identifier>s?' | %w[EpicReader]
            'How many days ago was %<epic_identifier>s epic created?' | %w[EpicReader]
          end
          # rubocop: enable Layout/LineLength

          with_them do
            it_behaves_like 'successful prompt processing'
          end
        end

        context 'with `this epic, direct answer using current resource`' do
          let(:resource) { epic }

          where(:input_template, :tools) do
            'Can you list all labels on this epic?'       | %w[]
            'How many days ago was current epic created?' | %w[]
          end

          with_them do
            let(:input) { input_template }

            it_behaves_like 'successful prompt processing'
          end
        end
      end

      context 'with chat history' do
        let(:history) do
          [
            { role: 'user', content: "What is epic #{epic.to_reference(full: true)} about?" },
            {
              role: 'assistant', content: "The summary of epic is:\n\n## Provider Comparison\n" \
                                          "- Difficulty in evaluating which provider is better \n" \
                                          "- Both providers have pros and cons\n" \
                                          "- Consider using objective measure to compare the providers\n"
            }
          ]
        end

        before do
          uuid = SecureRandom.uuid

          history.each do |message_data|
            build(:ai_chat_message, message_data.merge(user: user, request_id: uuid)).save!
          end
        end

        # rubocop: disable Layout/LineLength -- keep table structure readable
        where(:input_template, :tools) do
          # evaluation of questions which involve processing of other resources is not reliable yet
          # because the EpicReader tool assumes we work with single resource:
          # EpicReader overrides context.resource
          'Can you provide more details about that epic?' | %w[EpicReader]
          # Translation would have to be explicitly allowed in prompt rules first
          'Can you reword your answer?' | []
          'Can you explain your third point in different words?' | []
        end
        # rubocop: enable Layout/LineLength

        with_them do
          let(:input) { format(input_template) }

          it_behaves_like 'successful prompt processing'
        end
      end
    end

    context 'when asked about CI/CD' do
      where(:input_template, :tools) do
        'How do I configure CI/CD pipeline to deploy a ruby application to k8s?' |
          ['CiEditorAssistant']
        'Please help me configure a CI/CD pipeline for node application that would run lint and unit tests.' |
          ['CiEditorAssistant']
        'Please provide a .gitlab-ci.yaml config for running a review app for merge requests?' |
          ['CiEditorAssistant']
        'How do I optimize my pipelines so that they do not cost so much money?' |
          ['CiEditorAssistant']
        'How can I migrate from GitHub Actions to GitLab CI?' |
          ['CiEditorAssistant']
      end

      with_them do
        let(:input) { format(input_template) }

        it_behaves_like 'successful prompt processing'
      end
    end

    context 'when asked general questions' do
      let(:input) { format('What is your name?') }

      it 'answers question about a name', :aggregate_failures do
        answer = executor.execute

        expect(answer.response_body).to match('GitLab Duo Chat')
      end
    end

    context 'with selected code present' do
      let(:current_file) do
        {
          file_name: 'test.rb',
          selected_text: <<~TEXT
            def hello_world
              puts "Hello, World"
            end
          TEXT
        }
      end

      context 'when asked about writing tests' do
        where(:input_template, :tools) do
          'Write tests for selected code' | []
          '/tests'                        | %w[WriteTests]
          '/tests integration'            | %w[WriteTests]
        end

        with_them do
          let(:input) { format(input_template) }

          it_behaves_like 'successful prompt processing'
        end
      end

      context 'when refactoring selected code' do
        where(:input_template, :tools) do
          'Refactor this code'     | []
          '/refactor'              | %w[RefactorCode]
          '/refactor input params' | %w[RefactorCode]
        end

        with_them do
          let(:input) { format(input_template) }

          it_behaves_like 'successful prompt processing'
        end
      end

      context 'when explaining selected code' do
        where(:input_template, :tools) do
          'Explain this code'     | []
          '/explain'              | %w[ExplainCode]
          '/explain return value' | %w[ExplainCode]
        end

        with_them do
          let(:input) { format(input_template) }

          it_behaves_like 'successful prompt processing'
        end
      end
    end
  end
end
