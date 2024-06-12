# frozen_string_literal: true

RSpec.shared_examples 'anthropic prompt' do
  let(:language) { instance_double(CodeSuggestions::ProgrammingLanguage, x_ray_lang: x_ray_lang) }
  let(:language_name) { 'Go' }
  let(:x_ray_lang) { nil }

  let(:examples) do
    [
      { 'example' => 'func hello() {', 'response' => 'func hello() {<new_code>fmt.Println("hello")' }
    ]
  end

  let(:prefix) do
    <<~PREFIX
      package main

      import "fmt"

      func main() {
    PREFIX
  end

  let(:file_name) { 'main.go' }
  let(:model_name) { 'claude-3-sonnet-20240229' }
  let(:comment) { 'Generate the best possible code based on instructions.' }
  let(:context) { nil }
  let(:instruction) { instance_double(CodeSuggestions::Instruction, instruction: comment, trigger_type: 'comment') }

  let(:unsafe_params) do
    {
      'current_file' => {
        'file_name' => file_name,
        'content_above_cursor' => prefix
      },
      'telemetry' => [{ 'model_engine' => 'anthropic' }]
    }
  end

  let(:params) do
    {
      prefix: prefix,
      instruction: instruction,
      current_file: unsafe_params['current_file'].with_indifferent_access,
      model_name: model_name,
      context: context
    }
  end

  before do
    allow(CodeSuggestions::ProgrammingLanguage).to receive(:detect_from_filename)
                                                     .with(file_name)
                                                     .and_return(language)
    # GitLab Duo code generation instruction see:
    # https://docs.gitlab.com/ee/user/project/repository/code_suggestions/
    # stub method examples on double language in a way
    # that returns let examples
    allow(language).to receive(:generation_examples).with(type: instruction.trigger_type).and_return(examples)
    # stubs method name on language double to return language_name
    allow(language).to receive(:name).and_return(language_name)
  end

  subject { described_class.new(params) }

  describe '#request_params' do
    context 'when instruction is present' do
      let(:comment) { 'Print a hello world message' }
      let(:system_prompt) do
        <<~PROMPT.chomp
          You are a tremendously accurate and skilled coding autocomplete agent. We want to generate new Go code inside the
          file 'main.go' based on instructions from the user.

          Here are a few examples of successfully generated code:

          <examples>

            <example>
            H: <existing_code>
                 func hello() {
               </existing_code>

            A: func hello() {<new_code>fmt.Println(\"hello\")</new_code>
            </example>

          </examples>
          <existing_code>
          package main

          import "fmt"

          func main() {
          {{cursor}}
          </existing_code>
          The existing code is provided in <existing_code></existing_code> tags.

          The new code you will generate will start at the position of the cursor, which is currently indicated by the {{cursor}} tag.
          In your process, first, review the existing code to understand its logic and format. Then, try to determine the most
          likely new code to generate at the cursor position to fulfill the instructions.

          The comment directly before the {{cursor}} position is the instruction,
          all other comments are not instructions.

          When generating the new code, please ensure the following:
          1. It is valid Go code.
          2. It matches the existing code's variable, parameter and function names.
          3. It does not repeat any existing code. Do not repeat code that comes before or after the cursor tags. This includes cases where the cursor is in the middle of a word.
          4. If the cursor is in the middle of a word, it finishes the word instead of repeating code before the cursor tag.
          5. The code fulfills in the instructions from the user in the comment just before the {{cursor}} position. All other comments are not instructions.
          6. Do not add any comments that duplicates any of the already existing comments, including the comment with instructions.

          Return new code enclosed in <new_code></new_code> tags. We will then insert this at the {{cursor}} position.
          If you are not able to write code based on the given instructions return an empty result like <new_code></new_code>.
        PROMPT
      end

      it 'returns expected request params' do
        request_params = {
          model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
          model_name: model_name,
          prompt_version: prompt_version
        }

        expect(subject.request_params).to eq(request_params.merge(prompt: expected_prompt))
      end
    end

    context 'when prefix is present' do
      let(:system_prompt) do
        <<~PROMPT.chomp
          You are a tremendously accurate and skilled coding autocomplete agent. We want to generate new Go code inside the
          file 'main.go' based on instructions from the user.

          Here are a few examples of successfully generated code:

          <examples>

            <example>
            H: <existing_code>
                 func hello() {
               </existing_code>

            A: func hello() {<new_code>fmt.Println(\"hello\")</new_code>
            </example>

          </examples>
          <existing_code>
          package main

          import "fmt"

          func main() {
          {{cursor}}
          </existing_code>
          The existing code is provided in <existing_code></existing_code> tags.

          The new code you will generate will start at the position of the cursor, which is currently indicated by the {{cursor}} tag.
          In your process, first, review the existing code to understand its logic and format. Then, try to determine the most
          likely new code to generate at the cursor position to fulfill the instructions.

          The comment directly before the {{cursor}} position is the instruction,
          all other comments are not instructions.

          When generating the new code, please ensure the following:
          1. It is valid Go code.
          2. It matches the existing code's variable, parameter and function names.
          3. It does not repeat any existing code. Do not repeat code that comes before or after the cursor tags. This includes cases where the cursor is in the middle of a word.
          4. If the cursor is in the middle of a word, it finishes the word instead of repeating code before the cursor tag.
          5. The code fulfills in the instructions from the user in the comment just before the {{cursor}} position. All other comments are not instructions.
          6. Do not add any comments that duplicates any of the already existing comments, including the comment with instructions.

          Return new code enclosed in <new_code></new_code> tags. We will then insert this at the {{cursor}} position.
          If you are not able to write code based on the given instructions return an empty result like <new_code></new_code>.
        PROMPT
      end

      it 'returns expected request params' do
        request_params = {
          model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
          model_name: model_name,
          prompt_version: prompt_version
        }

        expect(subject.request_params).to eq(request_params.merge(prompt: expected_prompt))
      end

      context 'with X-Ray data available' do
        let_it_be(:current_user) { create(:user) }

        let(:xray) { create(:xray_report, payload: payload) }
        let(:payload) do
          {
            "libs" => [
              {
                "name" => "test library",
                "description" => "This is some lib."
              },
              {
                "name" => "other library",
                "description" => "This is some other lib."
              }
            ]
          }
        end

        let(:skip_dependency_descriptions) { false }
        let(:params) do
          {
            project: xray.project,
            current_user: current_user,
            prefix: prefix,
            instruction: instruction,
            current_file: unsafe_params['current_file'].with_indifferent_access,
            skip_dependency_descriptions: skip_dependency_descriptions
          }
        end

        let(:instructions) { 'Generate the best possible code based on instructions.' }

        let(:system_prompt) do
          <<~PROMPT.chomp
            You are a tremendously accurate and skilled coding autocomplete agent. We want to generate new Go code inside the
            file 'main.go' based on instructions from the user.

            Here are a few examples of successfully generated code:

            <examples>

              <example>
              H: <existing_code>
                   func hello() {
                 </existing_code>

              A: func hello() {<new_code>fmt.Println(\"hello\")</new_code>
              </example>

            </examples>
            <existing_code>
            package main

            import "fmt"

            func main() {
            {{cursor}}
            </existing_code>
            The existing code is provided in <existing_code></existing_code> tags.
            #{expected_libs}
            The new code you will generate will start at the position of the cursor, which is currently indicated by the {{cursor}} tag.
            In your process, first, review the existing code to understand its logic and format. Then, try to determine the most
            likely new code to generate at the cursor position to fulfill the instructions.

            The comment directly before the {{cursor}} position is the instruction,
            all other comments are not instructions.

            When generating the new code, please ensure the following:
            1. It is valid Go code.
            2. It matches the existing code's variable, parameter and function names.
            3. It does not repeat any existing code. Do not repeat code that comes before or after the cursor tags. This includes cases where the cursor is in the middle of a word.
            4. If the cursor is in the middle of a word, it finishes the word instead of repeating code before the cursor tag.
            5. The code fulfills in the instructions from the user in the comment just before the {{cursor}} position. All other comments are not instructions.
            6. Do not add any comments that duplicates any of the already existing comments, including the comment with instructions.

            Return new code enclosed in <new_code></new_code> tags. We will then insert this at the {{cursor}} position.
            If you are not able to write code based on the given instructions return an empty result like <new_code></new_code>.
          PROMPT
        end

        let(:expected_libs) do
          <<~LIBS
            <libs>
            test library: This is some lib.
            other library: This is some other lib.
            </libs>
            The list of available libraries is provided in <libs></libs> tags.
          LIBS
        end

        before do
          allow(::Projects::XrayReport).to receive(:for_project).and_call_original
          allow(::Projects::XrayReport).to receive(:for_lang).and_return([xray])
        end

        describe 'internal events tracking' do
          subject { described_class.new(params).request_params }

          it_behaves_like 'internal event tracking' do
            let(:event) { 'include_repository_xray_data_into_code_generation_prompt' }
            let(:project) { xray.project }
            let(:namespace) { project.namespace }
            let(:user) { current_user }
          end
        end

        it 'fetches X-Ray data' do
          subject.request_params

          expect(::Projects::XrayReport).to have_received(:for_project).with(xray.project)
          expect(::Projects::XrayReport).to have_received(:for_lang).with(x_ray_lang)
        end

        it 'returns expected request params' do
          request_params = {
            model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
            prompt_version: prompt_version
          }

          expect(subject.request_params).to eq(request_params.merge(prompt: expected_prompt))
        end

        context 'when model_name is missing' do
          before do
            params.delete(:model_name)
          end

          it 'does not include model_name in request params' do
            request_params = {
              model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
              prompt_version: prompt_version
            }

            expect(subject.request_params).to eq(request_params.merge(prompt: expected_prompt))
          end
        end

        context 'when X-Ray data exceeds maximum limit' do
          let(:expected_libs) do
            <<~LIBS
              <libs>
              test library: This is some lib.
              </libs>
              The list of available libraries is provided in <libs></libs> tags.
            LIBS
          end

          before do
            stub_const("CodeSuggestions::Prompts::CodeGeneration::AnthropicMessages::MAX_LIBS_COUNT", 1)
          end

          it 'trims libs content' do
            request_params = {
              model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
              prompt_version: prompt_version
            }

            expect(subject.request_params).to eq(request_params.merge(prompt: expected_prompt))
          end
        end

        context 'when skip_dependency_descriptions is true' do
          let(:skip_dependency_descriptions) { true }
          let(:expected_libs) do
            <<~LIBS
              <libs>
              test library
              other library
              </libs>
              The list of available libraries is provided in <libs></libs> tags.
            LIBS
          end

          it 'provides only libs names' do
            request_params = {
              model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
              prompt_version: prompt_version
            }

            expect(subject.request_params).to eq(request_params.merge(prompt: expected_prompt))
          end

          context 'when X-Ray data exceeds maximum limit' do
            before do
              stub_const("CodeSuggestions::Prompts::CodeGeneration::AnthropicMessages::MAX_LIBS_COUNT", 1)
            end

            it 'does not trim libs content' do
              request_params = {
                model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
                prompt_version: prompt_version
              }

              expect(subject.request_params).to eq(request_params.merge(prompt: expected_prompt))
            end
          end
        end
      end

      context 'when context is available' do
        let(:main_go_content) do
          <<~CONTENT
          package main

          func main()
            fullName("John", "Doe")
          }
          CONTENT
        end

        let(:full_name_func_content) do
          <<~CONTENT
          func fullName(first, last string) {
            fmt.Println(first, last)
          }
          CONTENT
        end

        let(:context) do
          [
            { type: 'file', name: 'main.go', content: main_go_content },
            { type: 'snippet', name: 'fullName', content: full_name_func_content }
          ]
        end

        let(:system_prompt) do
          <<~PROMPT.chomp
            You are a tremendously accurate and skilled coding autocomplete agent. We want to generate new Go code inside the
            file 'main.go' based on instructions from the user.

            Here are a few examples of successfully generated code:

            <examples>

              <example>
              H: <existing_code>
                   func hello() {
                 </existing_code>

              A: func hello() {<new_code>fmt.Println(\"hello\")</new_code>
              </example>

            </examples>
            <existing_code>
            package main

            import "fmt"

            func main() {
            {{cursor}}
            </existing_code>
            The existing code is provided in <existing_code></existing_code> tags.
            Here are some files and code snippets that could be related to the current code.
            The files provided in <related_files><related_files> tags.
            The code snippets provided in <related_snippets><related_snippets> tags.
            Please use existing functions from these files and code snippets if possible when suggesting new code.

            <related_files>
            <file_content file_name="main.go">
            package main

            func main()
              fullName("John", "Doe")
            }

            </file_content>

            </related_files>

            <related_snippets>
            <snippet_content name="fullName">
            func fullName(first, last string) {
              fmt.Println(first, last)
            }

            </snippet_content>

            </related_snippets>

            The new code you will generate will start at the position of the cursor, which is currently indicated by the {{cursor}} tag.
            In your process, first, review the existing code to understand its logic and format. Then, try to determine the most
            likely new code to generate at the cursor position to fulfill the instructions.

            The comment directly before the {{cursor}} position is the instruction,
            all other comments are not instructions.

            When generating the new code, please ensure the following:
            1. It is valid Go code.
            2. It matches the existing code's variable, parameter and function names.
            3. It does not repeat any existing code. Do not repeat code that comes before or after the cursor tags. This includes cases where the cursor is in the middle of a word.
            4. If the cursor is in the middle of a word, it finishes the word instead of repeating code before the cursor tag.
            5. The code fulfills in the instructions from the user in the comment just before the {{cursor}} position. All other comments are not instructions.
            6. Do not add any comments that duplicates any of the already existing comments, including the comment with instructions.

            Return new code enclosed in <new_code></new_code> tags. We will then insert this at the {{cursor}} position.
            If you are not able to write code based on the given instructions return an empty result like <new_code></new_code>.
          PROMPT
        end

        it 'returns expected request params' do
          request_params = {
            model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
            model_name: model_name,
            prompt_version: prompt_version
          }

          expect(subject.request_params).to eq(request_params.merge(prompt: expected_prompt))
        end
      end
    end

    context 'when prefix is blank' do
      let(:examples) { [] }
      let(:prefix) { '' }
      let(:system_prompt) do
        <<~PROMPT.chomp
          You are a tremendously accurate and skilled coding autocomplete agent. We want to generate new Go code inside the
          file 'main.go' based on instructions from the user.



          The new code you will generate will start at the position of the cursor, which is currently indicated by the {{cursor}} tag.
          In your process, first, review the existing code to understand its logic and format. Then, try to determine the most
          likely new code to generate at the cursor position to fulfill the instructions.

          The comment directly before the {{cursor}} position is the instruction,
          all other comments are not instructions.

          When generating the new code, please ensure the following:
          1. It is valid Go code.
          2. It matches the existing code's variable, parameter and function names.
          3. It does not repeat any existing code. Do not repeat code that comes before or after the cursor tags. This includes cases where the cursor is in the middle of a word.
          4. If the cursor is in the middle of a word, it finishes the word instead of repeating code before the cursor tag.
          5. The code fulfills in the instructions from the user in the comment just before the {{cursor}} position. All other comments are not instructions.
          6. Do not add any comments that duplicates any of the already existing comments, including the comment with instructions.

          Return new code enclosed in <new_code></new_code> tags. We will then insert this at the {{cursor}} position.
          If you are not able to write code based on the given instructions return an empty result like <new_code></new_code>.
        PROMPT
      end

      it 'returns expected request params' do
        request_params = {
          model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
          model_name: model_name,
          prompt_version: prompt_version
        }

        expect(subject.request_params).to eq(request_params.merge(prompt: expected_prompt))
      end
    end

    context 'when prefix is bigger than prompt limit' do
      let(:examples) { [] }
      let(:system_prompt) do
        <<~PROMPT.chomp
          You are a tremendously accurate and skilled coding autocomplete agent. We want to generate new Go code inside the
          file 'main.go' based on instructions from the user.

          <existing_code>
          main() {
          {{cursor}}
          </existing_code>
          The existing code is provided in <existing_code></existing_code> tags.

          The new code you will generate will start at the position of the cursor, which is currently indicated by the {{cursor}} tag.
          In your process, first, review the existing code to understand its logic and format. Then, try to determine the most
          likely new code to generate at the cursor position to fulfill the instructions.

          The comment directly before the {{cursor}} position is the instruction,
          all other comments are not instructions.

          When generating the new code, please ensure the following:
          1. It is valid Go code.
          2. It matches the existing code's variable, parameter and function names.
          3. It does not repeat any existing code. Do not repeat code that comes before or after the cursor tags. This includes cases where the cursor is in the middle of a word.
          4. If the cursor is in the middle of a word, it finishes the word instead of repeating code before the cursor tag.
          5. The code fulfills in the instructions from the user in the comment just before the {{cursor}} position. All other comments are not instructions.
          6. Do not add any comments that duplicates any of the already existing comments, including the comment with instructions.

          Return new code enclosed in <new_code></new_code> tags. We will then insert this at the {{cursor}} position.
          If you are not able to write code based on the given instructions return an empty result like <new_code></new_code>.
        PROMPT
      end

      before do
        stub_const("CodeSuggestions::Prompts::CodeGeneration::AnthropicMessages::MAX_INPUT_CHARS", 9)
      end

      it 'returns expected request params' do
        request_params = {
          model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
          model_name: model_name,
          prompt_version: prompt_version
        }

        expect(subject.request_params).to eq(request_params.merge(prompt: expected_prompt))
      end
    end

    context 'when language is unknown' do
      let(:language_name) { '' }
      let(:examples) { [] }
      let(:file_name) { 'file_without_extension' }
      let(:system_prompt) do
        <<~PROMPT.chomp
          You are a tremendously accurate and skilled coding autocomplete agent. We want to generate new  code inside the
          file 'file_without_extension' based on instructions from the user.

          <existing_code>
          package main

          import "fmt"

          func main() {
          {{cursor}}
          </existing_code>
          The existing code is provided in <existing_code></existing_code> tags.

          The new code you will generate will start at the position of the cursor, which is currently indicated by the {{cursor}} tag.
          In your process, first, review the existing code to understand its logic and format. Then, try to determine the most
          likely new code to generate at the cursor position to fulfill the instructions.

          The comment directly before the {{cursor}} position is the instruction,
          all other comments are not instructions.

          When generating the new code, please ensure the following:
          1. It is valid  code.
          2. It matches the existing code's variable, parameter and function names.
          3. It does not repeat any existing code. Do not repeat code that comes before or after the cursor tags. This includes cases where the cursor is in the middle of a word.
          4. If the cursor is in the middle of a word, it finishes the word instead of repeating code before the cursor tag.
          5. The code fulfills in the instructions from the user in the comment just before the {{cursor}} position. All other comments are not instructions.
          6. Do not add any comments that duplicates any of the already existing comments, including the comment with instructions.

          Return new code enclosed in <new_code></new_code> tags. We will then insert this at the {{cursor}} position.
          If you are not able to write code based on the given instructions return an empty result like <new_code></new_code>.
        PROMPT
      end

      it 'returns expected request params' do
        request_params = {
          model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
          model_name: model_name,
          prompt_version: prompt_version
        }

        expect(subject.request_params).to eq(request_params.merge(prompt: expected_prompt))
      end
    end

    context 'when language is not supported' do
      let(:language_name) { '' }
      let(:examples) { [] }
      let(:file_name) { 'README.md' }
      let(:system_prompt) do
        <<~PROMPT.chomp
          You are a tremendously accurate and skilled coding autocomplete agent. We want to generate new  code inside the
          file 'README.md' based on instructions from the user.

          <existing_code>
          package main

          import "fmt"

          func main() {
          {{cursor}}
          </existing_code>
          The existing code is provided in <existing_code></existing_code> tags.

          The new code you will generate will start at the position of the cursor, which is currently indicated by the {{cursor}} tag.
          In your process, first, review the existing code to understand its logic and format. Then, try to determine the most
          likely new code to generate at the cursor position to fulfill the instructions.

          The comment directly before the {{cursor}} position is the instruction,
          all other comments are not instructions.

          When generating the new code, please ensure the following:
          1. It is valid  code.
          2. It matches the existing code's variable, parameter and function names.
          3. It does not repeat any existing code. Do not repeat code that comes before or after the cursor tags. This includes cases where the cursor is in the middle of a word.
          4. If the cursor is in the middle of a word, it finishes the word instead of repeating code before the cursor tag.
          5. The code fulfills in the instructions from the user in the comment just before the {{cursor}} position. All other comments are not instructions.
          6. Do not add any comments that duplicates any of the already existing comments, including the comment with instructions.

          Return new code enclosed in <new_code></new_code> tags. We will then insert this at the {{cursor}} position.
          If you are not able to write code based on the given instructions return an empty result like <new_code></new_code>.
        PROMPT
      end

      it 'returns expected request params' do
        request_params = {
          model_provider: ::CodeSuggestions::TaskFactory::ANTHROPIC,
          model_name: model_name,
          prompt_version: prompt_version
        }

        expect(subject.request_params).to eq(request_params.merge(prompt: expected_prompt))
      end
    end
  end
end
