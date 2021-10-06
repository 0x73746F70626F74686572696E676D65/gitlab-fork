# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GithubImport::Representation::DiffNote do
  let(:hunk) do
    '@@ -1 +1 @@
    -Hello
    +Hello world'
  end

  let(:created_at) { Time.new(2017, 1, 1, 12, 00) }
  let(:updated_at) { Time.new(2017, 1, 1, 12, 15) }

  shared_examples 'a DiffNote' do
    it 'returns an instance of DiffNote' do
      expect(note).to be_an_instance_of(described_class)
    end

    context 'the returned DiffNote' do
      it 'includes the number of the note' do
        expect(note.noteable_id).to eq(42)
      end

      it 'includes the file path of the diff' do
        expect(note.file_path).to eq('README.md')
      end

      it 'includes the commit ID' do
        expect(note.commit_id).to eq('123abc')
      end

      it 'includes the user details' do
        expect(note.author)
          .to be_an_instance_of(Gitlab::GithubImport::Representation::User)

        expect(note.author.id).to eq(4)
        expect(note.author.login).to eq('alice')
      end

      it 'includes the note body' do
        expect(note.note).to eq('Hello world')
      end

      it 'includes the created timestamp' do
        expect(note.created_at).to eq(created_at)
      end

      it 'includes the updated timestamp' do
        expect(note.updated_at).to eq(updated_at)
      end

      it 'includes the GitHub ID' do
        expect(note.note_id).to eq(1)
      end

      it 'returns the noteable type' do
        expect(note.noteable_type).to eq('MergeRequest')
      end
    end
  end

  describe '.from_api_response' do
    let(:response) do
      double(
        :response,
        html_url: 'https://github.com/foo/bar/pull/42',
        path: 'README.md',
        commit_id: '123abc',
        original_commit_id: 'original123abc',
        diff_hunk: hunk,
        user: double(:user, id: 4, login: 'alice'),
        body: 'Hello world',
        created_at: created_at,
        updated_at: updated_at,
        line: 23,
        start_line: nil,
        id: 1
      )
    end

    it_behaves_like 'a DiffNote' do
      let(:note) { described_class.from_api_response(response) }
    end

    it 'does not set the user if the response did not include a user' do
      allow(response)
        .to receive(:user)
        .and_return(nil)

      note = described_class.from_api_response(response)

      expect(note.author).to be_nil
    end

    it 'formats a suggestion in the note body' do
      allow(response)
        .to receive(:body)
        .and_return <<~BODY
      ```suggestion
      Hello World
      ```
      BODY

      note = described_class.from_api_response(response)

      expect(note.note).to eq <<~BODY
      ```suggestion:-0+0
      Hello World
      ```
      BODY
    end
  end

  describe '.from_json_hash' do
    let(:hash) do
      {
        'noteable_type' => 'MergeRequest',
        'noteable_id' => 42,
        'file_path' => 'README.md',
        'commit_id' => '123abc',
        'original_commit_id' => 'original123abc',
        'diff_hunk' => hunk,
        'author' => { 'id' => 4, 'login' => 'alice' },
        'note' => 'Hello world',
        'created_at' => created_at.to_s,
        'updated_at' => updated_at.to_s,
        'note_id' => 1
      }
    end

    it_behaves_like 'a DiffNote' do
      let(:note) { described_class.from_json_hash(hash) }
    end

    it 'does not convert the author if it was not specified' do
      hash.delete('author')

      note = described_class.from_json_hash(hash)

      expect(note.author).to be_nil
    end

    it 'formats a suggestion in the note body' do
      hash['note'] = <<~BODY
      ```suggestion
      Hello World
      ```
      BODY

      note = described_class.from_json_hash(hash)

      expect(note.note).to eq <<~BODY
      ```suggestion:-0+0
      Hello World
      ```
      BODY
    end
  end

  describe '#line_code' do
    it 'returns a String' do
      note = described_class.new(diff_hunk: hunk, file_path: 'README.md')

      expect(note.line_code).to be_an_instance_of(String)
    end
  end

  describe '#diff_hash' do
    it 'returns a Hash containing the diff details' do
      note = described_class.from_json_hash(
        'noteable_type' => 'MergeRequest',
        'noteable_id' => 42,
        'file_path' => 'README.md',
        'commit_id' => '123abc',
        'original_commit_id' => 'original123abc',
        'diff_hunk' => hunk,
        'author' => { 'id' => 4, 'login' => 'alice' },
        'note' => 'Hello world',
        'created_at' => created_at.to_s,
        'updated_at' => updated_at.to_s,
        'note_id' => 1
      )

      expect(note.diff_hash).to eq(
        diff: hunk,
        new_path: 'README.md',
        old_path: 'README.md',
        a_mode: '100644',
        b_mode: '100644',
        new_file: false
      )
    end
  end

  describe '#github_identifiers' do
    it 'returns a hash with needed identifiers' do
      github_identifiers = {
        noteable_id: 42,
        noteable_type: 'MergeRequest',
        note_id: 1
      }
      other_attributes = { something_else: '_something_else_' }
      note = described_class.new(github_identifiers.merge(other_attributes))

      expect(note.github_identifiers).to eq(github_identifiers)
    end
  end

  describe '#note' do
    it 'returns the given note' do
      hash = {
        'note': 'simple text'
      }

      note = described_class.new(hash)

      expect(note.note).to eq 'simple text'
    end

    it 'returns the suggestion formatted in the note' do
      hash = {
        'note': <<~BODY
        ```suggestion
        Hello World
        ```
        BODY
      }

      note = described_class.new(hash)

      expect(note.note).to eq <<~BODY
      ```suggestion:-0+0
      Hello World
      ```
      BODY
    end

    it 'returns the multi-line suggestion formatted in the note' do
      hash = {
        'start_line': 20,
        'end_line': 23,
        'note': <<~BODY
        ```suggestion
        Hello World
        ```
        BODY
      }

      note = described_class.new(hash)

      expect(note.note).to eq <<~BODY
      ```suggestion:-3+0
      Hello World
      ```
      BODY
    end
  end
end
