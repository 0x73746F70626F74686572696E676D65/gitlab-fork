# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe ::Gitlab::Housekeeper::Git do
  let(:logger) { instance_double(Logger, info: nil) }
  let(:git) { described_class.new(logger: logger) }
  let(:repository_path) { Pathname(Dir.mktmpdir) }
  let(:test_branch_name) { 'gitlab-housekeeper--some-class--test--branch_123' }
  let(:file_in_master) { 'file_in_master.txt' }
  let(:file_in_another_branch) { 'file_in_another_branch.txt' }

  def setup_master_branch
    File.write(file_in_master, 'File already in master!')

    ::Gitlab::Housekeeper::Shell.execute('git', 'init')
    ::Gitlab::Housekeeper::Shell.execute('git', 'checkout', '-b', 'master')
    ::Gitlab::Housekeeper::Shell.execute('git', 'add', file_in_master)
    ::Gitlab::Housekeeper::Shell.execute('git', 'commit', '-m', 'Initial commit!')
  end

  def setup_and_checkout_another_branch
    ::Gitlab::Housekeeper::Shell.execute('git', 'checkout', '-b', 'another-branch')

    File.write(file_in_another_branch, 'File in another unrelated branch should not be in new branch!')
    ::Gitlab::Housekeeper::Shell.execute('git', 'add', file_in_another_branch)
    ::Gitlab::Housekeeper::Shell.execute('git', 'commit', '-m', 'Commit in unrelated branch should not be included')
  end

  before do
    @previous_dir = Dir.pwd
    Dir.chdir(repository_path)

    # Make sure there is a master branch with something to branch from
    setup_master_branch
    setup_and_checkout_another_branch
  end

  after do
    Dir.chdir(@previous_dir) if @previous_dir # rubocop:disable RSpec/InstanceVariable -- let not suitable for before/after cleanup
    FileUtils.rm_rf(repository_path)
  end

  describe '#with_branch_from_branch and #commit_in_branch' do
    let(:file_not_to_commit) { repository_path.join('test_file_not_to_commit.txt') }
    let(:test_file1) { 'test_file1.txt' }
    let(:test_file2) { 'files/test_file2.txt' }

    it 'commits the given change details to the given branch name' do
      change = ::Gitlab::Housekeeper::Change.new
      change.title = "The commit title"
      change.description = <<~COMMIT
      The commit description can be
      split over multiple lines!
      COMMIT

      change.keep_class = Object
      change.identifiers = %w[GitlabHousekeeper::SomeClass Test/Branch_123]

      Dir.mkdir('files')
      File.write(test_file1, "Content in file 1!")
      File.write(test_file2, "Other content in file 2!")
      File.write(file_not_to_commit, 'Do not commit!')

      change.changed_files = [test_file1, test_file2]

      branch_name = nil
      git.with_branch_from_branch do
        branch_name = git.commit_in_branch(change)
      end

      expect(branch_name).to eq(test_branch_name)

      branches = ::Gitlab::Housekeeper::Shell.execute('git', 'branch')
      expect(branches).to include(branch_name)

      current_commit_on_another_branch = ::Gitlab::Housekeeper::Shell.execute('git', 'show')
      expect(current_commit_on_another_branch).to include('Commit in unrelated branch should not be included')

      expected = <<~COMMIT
          The commit title

          The commit description can be
          split over multiple lines!

          This change was generated by
          [gitlab-housekeeper](https://gitlab.com/gitlab-org/gitlab/-/tree/master/gems/gitlab-housekeeper)
          using the Object keep.

          To provide feedback on your experience with `gitlab-housekeeper` please comment in
          <https://gitlab.com/gitlab-org/gitlab/-/issues/442003>.

          Changelog: other


      diff --git a/files/test_file2.txt b/files/test_file2.txt
      new file mode 100644
      index 0000000..ff205e0
      --- /dev/null
      +++ b/files/test_file2.txt
      @@ -0,0 +1 @@
      +Other content in file 2!
      \\ No newline at end of file
      diff --git a/test_file1.txt b/test_file1.txt
      new file mode 100644
      index 0000000..8dd3371
      --- /dev/null
      +++ b/test_file1.txt
      @@ -0,0 +1 @@
      +Content in file 1!
      \\ No newline at end of file
      COMMIT

      commit = ::Gitlab::Housekeeper::Shell.execute('git', 'show', branch_name).gsub(/\s/, '')
      expected_without_whitespace = expected.gsub(/\s/, '')
      expect(commit).to include(expected_without_whitespace)

      ::Gitlab::Housekeeper::Shell.execute('git', 'checkout', branch_name)
      expect(File).to exist(file_in_master)
      expect(File).not_to exist(file_in_another_branch)
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
