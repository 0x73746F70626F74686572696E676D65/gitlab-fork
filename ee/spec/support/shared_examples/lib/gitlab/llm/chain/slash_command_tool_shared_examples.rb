# frozen_string_literal: true

# Shared examples for slash command tools,
# the following resources should be set when using these examples:
# * tool
# * prompt_class
# * input
# * extra_params
RSpec.shared_examples 'slash command tool' do
  let(:filename) { 'test.py' }
  let(:expected_params) do
    {
      input: input,
      selected_text: 'selected text',
      language_info: 'The code is written in Python and stored as test.py',
      file_content: "Here is the content of the file user is working with:\n" \
                    "<file>\n  code aboveselected textcode below\n</file>\n"
    }.merge(extra_params)
  end

  before do
    allow(ai_request_double).to receive(:request).and_return('response')
    allow(tool).to receive(:provider_prompt_class).and_return(prompt_class)
    context.current_file = {
      file_name: filename,
      selected_text: 'selected text',
      content_above_cursor: 'code above',
      content_below_cursor: 'code below'
    }
  end

  it 'calls prompt with correct params' do
    expect(prompt_class).to receive(:prompt).with(expected_params)

    tool.execute
  end

  context 'when slash command is used' do
    let(:instruction) { 'command instruction' }
    let(:command_prompt_options) { { input: instruction } }
    let(:command) { instance_double(Gitlab::Llm::Chain::SlashCommand, prompt_options: command_prompt_options) }
    let(:options) { { input: '/explain something' } }

    it 'calls prompt with correct params' do
      expect(prompt_class).to receive(:prompt).with(expected_params.merge(input: instruction))

      tool.execute
    end
  end

  context 'when the language is unknown' do
    let(:filename) { 'filename' }

    it 'uses empty language info' do
      expect(prompt_class).to receive(:prompt).with(a_hash_including(language_info: ''))

      tool.execute
    end
  end

  context 'when content params are empty' do
    before do
      context.current_file[:content_above_cursor] = ''
      context.current_file[:content_below_cursor] = ''
    end

    it 'uses empty file content' do
      expect(prompt_class).to receive(:prompt).with(a_hash_including(file_content: ''))

      tool.execute
    end
  end

  context 'when content params are too big' do
    before do
      stub_const("#{prompt_class}::MAX_CHARACTERS", 150)
    end

    it 'trims the content' do
      trimmed_content = "Here is a part of the content of the file user is working with:\n" \
                        "<file>\n  code aboveselected textcode \n</file>\n"
      expect(prompt_class).to receive(:prompt).with(a_hash_including(file_content: trimmed_content))

      tool.execute
    end
  end

  context 'when stream_response_service is set' do
    let(:stream_response_handler) { instance_double(::Gitlab::Llm::ResponseService) }

    before do
      allow(ai_request_double).to receive(:request).and_yield("Hello").and_yield(" World")
    end

    it 'streams the final answer' do
      first_response_double = double
      second_response_double = double

      allow(Gitlab::Llm::Chain::StreamedResponseModifier).to receive(:new).with("Hello", { chunk_id: 1 })
        .and_return(first_response_double)

      allow(Gitlab::Llm::Chain::StreamedResponseModifier).to receive(:new).with(" World", { chunk_id: 2 })
        .and_return(second_response_double)

      expect(stream_response_handler).to receive(:execute).with(
        response: first_response_double,
        options: { chunk_id: 1 }
      )
      expect(stream_response_handler).to receive(:execute).with(
        response: second_response_double,
        options: { chunk_id: 2 }
      )

      tool.execute
    end
  end
end
