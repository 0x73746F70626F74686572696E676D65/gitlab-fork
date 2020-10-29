# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'issuable import csv service' do |issuable_type|
  let(:project) { create(:project) }
  let(:user) { create(:user) }

  subject { service }

  shared_examples_for 'an issuable importer' do
    it 'records the import attempt if resource is an issue' do
      if issuable_type == 'issue'
        expect { subject }
          .to change { Issues::CsvImport.where(project: project, user: user).count }
          .by 1
      end
    end
  end

  shared_examples_for 'importer with email notification' do
    it 'notifies user of import result' do
      if issuable_type == 'issue'
        expect(Notify).to receive_message_chain(email_method, :deliver_later)

        subject
      end
    end
  end

  describe '#execute' do
    context 'invalid file' do
      let(:file) { fixture_file_upload('spec/fixtures/banana_sample.gif') }

      it 'returns invalid file error' do
        expect(subject[:success]).to eq(0)
        expect(subject[:parse_error]).to eq(true)
      end

      it_behaves_like 'importer with email notification'
      it_behaves_like 'an issuable importer'
    end

    context 'with a file generated by Gitlab CSV export' do
      let(:file) { fixture_file_upload('spec/fixtures/csv_gitlab_export.csv') }

      it 'imports the CSV without errors' do
        expect(subject[:success]).to eq(4)
        expect(subject[:error_lines]).to eq([])
        expect(subject[:parse_error]).to eq(false)
      end

      it 'correctly sets the issuable attributes' do
        expect { subject }.to change { issuables.count }.by 4

        expect(issuables.reload.last).to have_attributes(
          title: 'Test Title',
          description: 'Test Description'
        )
      end

      it_behaves_like 'importer with email notification'
      it_behaves_like 'an issuable importer'
    end

    context 'comma delimited file' do
      let(:file) { fixture_file_upload('spec/fixtures/csv_comma.csv') }

      it 'imports CSV without errors' do
        expect(subject[:success]).to eq(3)
        expect(subject[:error_lines]).to eq([])
        expect(subject[:parse_error]).to eq(false)
      end

      it 'correctly sets the issuable attributes' do
        expect { subject }.to change { issuables.count }.by 3

        expect(issuables.reload.last).to have_attributes(
          title: 'Title with quote"',
          description: 'Description'
        )
      end

      it_behaves_like 'importer with email notification'
      it_behaves_like 'an issuable importer'
    end

    context 'tab delimited file with error row' do
      let(:file) { fixture_file_upload('spec/fixtures/csv_tab.csv') }

      it 'imports CSV with some error rows' do
        expect(subject[:success]).to eq(2)
        expect(subject[:error_lines]).to eq([3])
        expect(subject[:parse_error]).to eq(false)
      end

      it 'correctly sets the issuable attributes' do
        expect { subject }.to change { issuables.count }.by 2

        expect(issuables.reload.last).to have_attributes(
          title: 'Hello',
          description: 'World'
        )
      end

      it_behaves_like 'importer with email notification'
      it_behaves_like 'an issuable importer'
    end

    context 'semicolon delimited file with CRLF' do
      let(:file) { fixture_file_upload('spec/fixtures/csv_semicolon.csv') }

      it 'imports CSV with a blank row' do
        expect(subject[:success]).to eq(3)
        expect(subject[:error_lines]).to eq([4])
        expect(subject[:parse_error]).to eq(false)
      end

      it 'correctly sets the issuable attributes' do
        expect { subject }.to change { issuables.count }.by 3

        expect(issuables.reload.last).to have_attributes(
          title: 'Hello',
          description: 'World'
        )
      end

      it_behaves_like 'importer with email notification'
      it_behaves_like 'an issuable importer'
    end
  end
end
