# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe Gitlab::Shell do
  let_it_be(:project) { create(:project, :repository) }

  let(:repository) { project.repository }
  let(:gitlab_shell) { described_class.new }

  before do
    described_class.instance_variable_set(:@secret_token, nil)
  end

  describe '.secret_token' do
    let(:secret_file) { 'tmp/tests/.secret_shell_test' }
    let(:link_file) { 'tmp/tests/shell-secret-test/.gitlab_shell_secret' }

    before do
      allow(Gitlab.config.gitlab_shell).to receive(:secret_file).and_return(secret_file)
      allow(Gitlab.config.gitlab_shell).to receive(:path).and_return('tmp/tests/shell-secret-test')
      FileUtils.mkdir('tmp/tests/shell-secret-test')
    end

    after do
      FileUtils.rm_rf('tmp/tests/shell-secret-test')
      FileUtils.rm_rf(secret_file)
    end

    shared_examples 'creates and links the secret token file' do
      it 'creates and links the secret token file' do
        secret_token = described_class.secret_token

        expect(File.exist?(secret_file)).to be(true)
        expect(File.read(secret_file).chomp).to eq(secret_token)
        expect(File.symlink?(link_file)).to be(true)
        expect(File.readlink(link_file)).to eq(secret_file)
      end
    end

    describe 'memoized secret_token' do
      before do
        described_class.ensure_secret_token!
      end

      it_behaves_like 'creates and links the secret token file'
    end

    context 'when link_file is a broken symbolic link' do
      before do
        File.symlink('tmp/tests/non_existing_file', link_file)
        described_class.ensure_secret_token!
      end

      it_behaves_like 'creates and links the secret token file'
    end

    context 'when secret_file exists' do
      let(:secret_token) { 'secret-token' }

      before do
        File.write(secret_file, 'secret-token')
        described_class.ensure_secret_token!
      end

      it_behaves_like 'creates and links the secret token file'

      it 'reads the token from the existing file' do
        expect(described_class.secret_token).to eq(secret_token)
      end
    end
  end

  describe 'namespace actions' do
    subject { described_class.new }

    let(:storage) { Gitlab.config.repositories.storages.each_key.first }

    describe '#repository_exists?' do
      context 'when the repository does not exist' do
        it 'returns false' do
          expect(subject.repository_exists?(storage, "non-existing.git")).to be(false)
        end
      end

      context 'when the repository exists' do
        it 'returns true' do
          project = create(:project, :repository, :legacy_storage)

          expect(subject.repository_exists?(storage, project.repository.disk_path + ".git")).to be(true)
        end
      end
    end
  end
end
