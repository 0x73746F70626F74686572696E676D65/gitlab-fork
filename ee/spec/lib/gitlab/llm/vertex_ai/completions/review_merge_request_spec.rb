# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::Completions::ReviewMergeRequest, feature_category: :code_review_workflow do
  let(:prompt_class) { Gitlab::Llm::Templates::ReviewMergeRequest }
  let(:tracking_context) { { action: :review_merge_request, request_id: 'uuid' } }
  let(:options) { {} }
  let(:response_modifier) { double }
  let_it_be(:llm_bot) { create(:user, :llm_bot) }
  let_it_be(:user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request) }
  let_it_be(:diff_refs) { merge_request.diff_refs }

  let(:ai_reviewable_diff_files) do
    [
      instance_double(
        Gitlab::Diff::File,
        old_path: 'NEW.md',
        new_path: 'NEW.md',
        diff_lines_by_hunk: [
          {
            added: [
              instance_double(Gitlab::Diff::Line, old_pos: 5, new_pos: 3),
              instance_double(Gitlab::Diff::Line, old_pos: 5, new_pos: 4)
            ],
            removed: [
              instance_double(Gitlab::Diff::Line, old_pos: 3, new_pos: 3),
              instance_double(Gitlab::Diff::Line, old_pos: 4, new_pos: 3)
            ]
          }
        ]
      ),
      instance_double(
        Gitlab::Diff::File,
        old_path: 'UPDATED.md',
        new_path: 'UPDATED.md',
        diff_lines_by_hunk: [
          {
            added: [],
            removed: [
              instance_double(Gitlab::Diff::Line, old_pos: 3, new_pos: 3),
              instance_double(Gitlab::Diff::Line, old_pos: 4, new_pos: 3)
            ]
          }
        ]
      )
    ]
  end

  let(:prompt_message) do
    build(:ai_message, :review_merge_request, user: user, resource: merge_request, request_id: 'uuid')
  end

  subject(:completion) { described_class.new(prompt_message, prompt_class, options) }

  before do
    allow(merge_request)
      .to receive(:ai_reviewable_diff_files)
      .and_return(ai_reviewable_diff_files)
  end

  describe '#execute' do
    let(:prompt) { 'This is a prompt' }

    let(:payload_parameters) do
      {
        temperature: 0,
        maxOutputTokens: 1024,
        topK: 40,
        topP: 0.95
      }
    end

    before do
      allow_next_instance_of(prompt_class) do |template|
        allow(template).to receive(:to_prompt).and_return(prompt)
      end

      allow(::Gitlab::Llm::VertexAi::Configuration)
        .to receive(:payload_parameters)
        .with(temperature: 0)
        .and_return(payload_parameters)
    end

    context 'when generated prompt is nil' do
      let(:prompt) { nil }

      it 'does not make a request to AI provider' do
        expect(Gitlab::Llm::VertexAi::Client).not_to receive(:new)

        completion.execute
      end
    end

    context 'when the chat client returns a successful response' do
      let(:example_answer) { 'Helpful review with suggestions' }

      let(:example_response) do
        {
          "predictions" => [
            {
              "content" => example_answer,
              "safetyAttributes" => {
                "categories" => ["Violent"],
                "scores" => [0.4000000059604645],
                "blocked" => false
              }
            }
          ]
        }
      end

      before do
        allow_next_instance_of(Gitlab::Llm::VertexAi::Client, user, unit_primitive: 'review_merge_request', tracking_context: tracking_context) do |client| # rubocop:disable Layout/LineLength -- follow-up
          allow(client)
            .to receive(:chat)
            .with(content: prompt, parameters: payload_parameters)
            .and_return(example_response.to_json)
        end
      end

      it 'calls Notes::CreateService#execute to create diff note on new and updated files' do
        new_file_create_note_params = {
          note: example_answer,
          noteable_id: merge_request.id,
          noteable_type: MergeRequest,
          position: {
            base_sha: diff_refs.base_sha,
            start_sha: diff_refs.start_sha,
            head_sha: diff_refs.head_sha,
            old_path: 'NEW.md',
            new_path: 'NEW.md',
            position_type: 'text',
            old_line: nil,
            new_line: 4,
            ignore_whitespace_change: false
          },
          type: 'DiffNote'
        }

        updated_file_create_note_params = {
          note: example_answer,
          noteable_id: merge_request.id,
          noteable_type: MergeRequest,
          position: {
            base_sha: diff_refs.base_sha,
            start_sha: diff_refs.start_sha,
            head_sha: diff_refs.head_sha,
            old_path: 'UPDATED.md',
            new_path: 'UPDATED.md',
            position_type: 'text',
            old_line: 4,
            new_line: nil,
            ignore_whitespace_change: false
          },
          type: 'DiffNote'
        }

        expect_next_instance_of(
          Notes::CreateService,
          merge_request.project,
          llm_bot,
          new_file_create_note_params
        ) do |svc|
          expect(svc).to receive(:execute)
        end

        expect_next_instance_of(
          Notes::CreateService,
          merge_request.project,
          llm_bot,
          updated_file_create_note_params
        ) do |svc|
          expect(svc).to receive(:execute)
        end

        completion.execute
      end
    end

    context 'when the chat client returns an unsuccessful response' do
      let(:error) { { error: { message: 'Error' } } }

      before do
        allow_next_instance_of(Gitlab::Llm::VertexAi::Client, user, unit_primitive: 'review_merge_request', tracking_context: tracking_context) do |client| # rubocop:disable Layout/LineLength -- follow-up
          allow(client)
            .to receive(:chat)
            .with(content: prompt, parameters: payload_parameters)
            .and_return(error.to_json)
        end
      end

      it 'does not call Notes::CreateService' do
        expect(Notes::CreateService).not_to receive(:new)

        completion.execute
      end
    end

    context 'when the AI response is empty' do
      before do
        allow_next_instance_of(Gitlab::Llm::VertexAi::Client, user, unit_primitive: 'review_merge_request', tracking_context: tracking_context) do |client| # rubocop:disable Layout/LineLength -- follow-up
          allow(client)
            .to receive(:chat)
            .with(content: prompt, parameters: payload_parameters)
            .and_return({})
        end
      end

      it 'does not call Notes::CreateService' do
        expect(Notes::CreateService).not_to receive(:new)

        completion.execute
      end

      it 'does not raise an error' do
        expect { completion.execute }.not_to raise_error
      end
    end
  end
end
