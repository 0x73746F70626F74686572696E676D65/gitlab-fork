# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module EpicReader
          class Executor < Identifier
            include Concerns::ReaderTooling

            RESOURCE_NAME = 'epic'
            NAME = 'EpicReader'
            HUMAN_NAME = 'Epic Search'
            DESCRIPTION = <<~PROMPT
            This tool retrieves the content of a specific epic
            ONLY if the user question fulfills the strict usage conditions below.

            **Strict Usage Conditions:**
            * **Condition 1: epic ID Provided:** This tool MUST be used ONLY when the user provides a valid epic ID.
            * **Condition 2: epic URL Context:** This tool MUST be used ONLY when the user is actively viewing a specific epic URL or a specific URL is provided by the user.

            **Do NOT** attempt to search for or identify epics based on descriptions, keywords, or user questions.

            **Action Input:**
            * The original question asked by the user.

            **Important:**  Reject any input that does not strictly adhere to the usage conditions above.
            Return a message stating you are unable to search for epics without a valid identifier.
            PROMPT

            EXAMPLE =
              <<~PROMPT
                Question: Please identify the author of &123 epic.
                Thought: You have access to the same resources as user who asks a question.
                  The question is about an epic, so you need to use "EpicReader" tool.
                  Based on this information you can present final answer.
                Action: EpicReader
                Action Input: Please identify the author of &123 epic.
              PROMPT

            PROVIDER_PROMPT_CLASSES = {
              ai_gateway: ::Gitlab::Llm::Chain::Tools::EpicReader::Prompts::Anthropic,
              anthropic: ::Gitlab::Llm::Chain::Tools::EpicReader::Prompts::Anthropic,
              vertex_ai: ::Gitlab::Llm::Chain::Tools::EpicReader::Prompts::VertexAi
            }.freeze

            SYSTEM_PROMPT = Utils::Prompt.as_system(
              <<~PROMPT
                You can fetch information about a resource called: an epic.
                An epic can be referenced by url or numeric IDs preceded by symbol.
                An epic can also be referenced by a GitLab reference.
                A GitLab reference ends with a number preceded by the delimiter & and contains one or more /.
                ResourceIdentifierType can only be one of [current, iid, url, reference]
                ResourceIdentifier can be number, url. If ResourceIdentifier is not a number or a url
                use "current".
                When you see a GitLab reference, ResourceIdentifierType should be reference.

                Make sure the response is a valid JSON. The answer should be just the JSON without any other commentary!
                References in the given question to the current epic can be also for example "this epic" or "that epic",
                referencing the epic that the user currently sees.
                Question: (the user question)
                Response (follow the exact JSON response):
                ```json
                {
                  "ResourceIdentifierType": <ResourceIdentifierType>
                  "ResourceIdentifier": <ResourceIdentifier>
                }
                ```

                Examples of epic reference identifier:

                Question: The user question or request may include https://some.host.name/some/long/path/-/epics/410692
                Response:
                ```json
                {
                  "ResourceIdentifierType": "url",
                  "ResourceIdentifier": "https://some.host.name/some/long/path/-/epics/410692"
                }
                ```

                Question: the user question or request may include: &12312312
                Response:
                ```json
                {
                  "ResourceIdentifierType": "iid",
                  "ResourceIdentifier": 12312312
                }
                ```

                Question: the user question or request may include long/groups/path&12312312
                Response:
                ```json
                {
                  "ResourceIdentifierType": "reference",
                  "ResourceIdentifier": "long/groups/path&12312312"
                }
                ```

                Question: Summarize the current epic
                Response:
                ```json
                {
                  "ResourceIdentifierType": "current",
                  "ResourceIdentifier": "current"
                }
                ```

                Begin!
              PROMPT
            )

            PROMPT_TEMPLATE = [
              SYSTEM_PROMPT,
              Utils::Prompt.as_assistant("%<suggestions>s"),
              Utils::Prompt.as_user("Question: %<input>s")
            ].freeze

            private

            def by_iid(resource_identifier)
              return unless group_from_context

              epics = group_from_context.epics.iid_in(resource_identifier.to_i)

              epics.first if epics.one?
            end

            def extract_resource(text, _type)
              project = extract_project
              return unless project

              extractor = Gitlab::ReferenceExtractor.new(project, context.current_user)
              extractor.analyze(text, {})
              epics = extractor.epics

              epics.first if epics.one?
            end

            def extract_project
              return projects_from_context.first unless projects_from_context.blank?

              # Epics belong to a group. The `ReferenceExtractor` expects a `project`
              # but does not use it for the extraction of epics.
              context.current_user.authorized_projects.first
            end

            def resource_name
              RESOURCE_NAME
            end
          end
        end
      end
    end
  end
end
