# frozen_string_literal: true

RSpec.shared_context 'secrets check context' do
  include_context 'secret detection error and log messages context'

  let_it_be(:user) { create(:user) }

  # Project is created with an empty repository, so
  # we create an initial commit to have a blob committed.
  let_it_be(:project) { create(:project, :empty_repo) }
  let_it_be(:repository) { project.repository }
  let_it_be(:initial_commit) do
    # An initial commit to use as the oldrev in `changes` object below.
    repository.commit_files(
      user,
      branch_name: 'master',
      message: 'Initial commit',
      actions: [
        { action: :create, file_path: 'README', content: 'Documentation goes here' }
      ]
    )
  end

  # Create a default `new_commit` for use cases in which we don't care much about blobs.
  let_it_be(:new_commit) { create_commit('.env' => 'BASE_URL=https://foo.bar') }

  # Define blob references as follows:
  #   1. old reference is used as the blob id for the initial commit.
  #   2. new reference is used as the blob id for commits created in before_all statements elsewhere.
  let(:old_blob_reference) { 'f3ac5ae18d057a11d856951f27b9b5b8043cf1ec' }
  let(:new_blob_reference) { 'fe29d93da4843da433e62711ace82db601eb4f8f' }
  let(:changes) do
    [
      {
        oldrev: initial_commit,
        newrev: new_commit,
        ref: 'refs/heads/master'
      }
    ]
  end

  # repository.blank_ref is used to denote a delete commit
  let(:delete_changes) do
    [
      {
        oldrev: initial_commit,
        newrev: repository.blank_ref,
        ref: 'refs/heads/master'
      }
    ]
  end

  # Set up the `changes_access` object to use below.
  let(:protocol) { 'ssh' }
  let(:timeout) { Gitlab::GitAccess::INTERNAL_TIMEOUT }
  let(:logger) { Gitlab::Checks::TimedLogger.new(timeout: timeout) }
  let(:user_access) { Gitlab::UserAccess.new(user, container: project) }
  let(:push_options) { nil }

  let(:changes_access) do
    Gitlab::Checks::ChangesAccess.new(
      changes,
      project: project,
      user_access: user_access,
      protocol: protocol,
      logger: logger,
      push_options: push_options
    )
  end

  let(:delete_changes_access) do
    Gitlab::Checks::ChangesAccess.new(
      delete_changes,
      project: project,
      user_access: user_access,
      protocol: protocol,
      logger: logger,
      push_options: push_options
    )
  end

  # We cannot really get the same Gitlab::Git::Blob objects even if we call `list_all_blobs` or `list_blobs`
  # directly in any of the specs (which is also not a very good idea) as the object ids will always
  # be different, so we expect the attributes of the returned object to match.
  let(:old_blob) { have_attributes(class: Gitlab::Git::Blob, id: old_blob_reference, size: 23) }
  let(:new_blob) { have_attributes(class: Gitlab::Git::Blob, id: new_blob_reference, size: 33) }

  # Used for mocking calls to `tree_entries` methods.
  let(:gitaly_pagination_cursor) { Gitaly::PaginationCursor.new(next_cursor: "") }
  let(:tree_entries) do
    [
      Gitlab::Git::Tree.new(
        id: new_blob_reference,
        type: :blob,
        mode: '100644',
        name: '.env',
        path: '.env',
        flat_path: '.env',
        commit_id: new_commit
      )
    ]
  end

  # Used for mocking calls to logger.
  let(:secret_detection_logger) { instance_double(::Gitlab::SecretDetectionLogger) }

  before do
    allow(::Gitlab::SecretDetectionLogger).to receive(:build).and_return(secret_detection_logger)

    # This fixes a regression when testing locally because scanning in subprocess using the
    # parallel gem calls `Kernel.at_exit` hook in gitaly_setup.rb when a subprocess is killed
    # which in turns kills gitaly/praefect processes midway through the test suite, resulting in
    # connection refused errors because the processes are no longer around.
    #
    # Instead, we set `RUN_IN_SUBPROCESS` to false so that we don't scan in sub-processes at all in tests.
    stub_const('Gitlab::SecretDetection::Scan::RUN_IN_SUBPROCESS', false)
  end

  before_all do
    project.add_developer(user)
  end

  subject(:secrets_check) { described_class.new(changes_access) }

  let(:delete_branch) { described_class.new(delete_changes_access) }
end

RSpec.shared_context 'secret detection error and log messages context' do
  let(:error_messages) { ::Gitlab::Checks::SecretsCheck::ERROR_MESSAGES }
  let(:log_messages) { ::Gitlab::Checks::SecretsCheck::LOG_MESSAGES }

  # Error messsages with formatting
  let(:failed_to_scan_regex_error) do
    format(error_messages[:failed_to_scan_regex_error], { blob_id: failed_to_scan_blob_reference })
  end

  let(:blob_timed_out_error) do
    format(error_messages[:blob_timed_out_error], { blob_id: timed_out_blob_reference })
  end

  let(:too_many_tree_entries_error) do
    format(error_messages[:too_many_tree_entries_error], { sha: new_commit })
  end

  # Log messages with formatting
  let(:finding_path) { '.env' }
  let(:finding_line_number) { 1 }
  let(:finding_description) { 'GitLab Personal Access Token' }
  let(:finding_path2) { 'test.txt' }
  let(:finding_line_number2) { 2 }
  let(:finding_description2) { 'GitLab Runner Authentication Token' }
  let(:finding_message_header) { format(log_messages[:finding_message_occurrence_header], { sha: new_commit }) }
  let(:finding_message_path) { format(log_messages[:finding_message_occurrence_path], { path: finding_path }) }
  let(:finding_message_path2) { format(log_messages[:finding_message_occurrence_path], { path: finding_path2 }) }
  let(:finding_message_occurrence_line) do
    format(
      log_messages[:finding_message_occurrence_line],
      {
        line_number: finding_line_number,
        description: finding_description
      }
    )
  end

  let(:finding_message_occurrence_line2) do
    format(
      log_messages[:finding_message_occurrence_line],
      {
        line_number: finding_line_number,
        description: finding_description2
      }
    )
  end

  let(:finding_message_multiple_occurrence_lines) do
    variables = {
      line_number: finding_line_number,
      description: finding_description
    }

    finding_message_path + format(log_messages[:finding_message_occurrence_line], variables) +
      finding_message_path + format(log_messages[:finding_message_occurrence_line],
        variables.merge(line_number: finding_line_number + 1))
  end

  let(:finding_message_same_blob_in_multiple_commits_header_path_and_lines) do
    message = finding_message_header
    message += finding_message_path
    message += finding_message_occurrence_line
    message += format(log_messages[:finding_message_occurrence_header], { sha: commit_with_same_blob })
    message += finding_message_path
    message += finding_message_occurrence_line
    message
  end

  let(:finding_message_multiple_files_occurrence_lines) do
    message = finding_message_header
    message += finding_message_path
    message += finding_message_occurrence_line
    message += finding_message_path2
    message += finding_message_occurrence_line2
    message
  end

  let(:finding_message_multiple_findings_on_same_line) do
    variables = {
      line_number: finding_line_number,
      description: finding_description
    }

    finding_message_path + format(log_messages[:finding_message_occurrence_line], variables) +
      finding_message_path + format(log_messages[:finding_message_occurrence_line],
        variables.merge(description: second_finding_description))
  end

  let(:finding_message_with_blob) do
    format(
      log_messages[:finding_message],
      {
        blob_id: new_blob_reference,
        line_number: finding_line_number,
        description: finding_description
      }
    )
  end

  let(:found_secrets_docs_link) do
    format(
      log_messages[:found_secrets_docs_link],
      {
        path: Rails.application.routes.url_helpers.help_page_url(
          Gitlab::Checks::SecretsCheck::DOCUMENTATION_PATH,
          anchor: Gitlab::Checks::SecretsCheck::DOCUMENTATION_PATH_ANCHOR
        )
      }
    )
  end
end

RSpec.shared_context 'quarantine directory exists' do
  let(:git_env) { { 'GIT_OBJECT_DIRECTORY_RELATIVE' => 'objects' } }
  let(:gitaly_commit_client) { instance_double(Gitlab::GitalyClient::CommitService) }

  let(:object_existence_map) do
    {
      old_blob_reference.to_s => true,
      new_blob_reference.to_s => false
    }
  end

  before do
    allow(Gitlab::Git::HookEnv).to receive(:all).with(repository.gl_repository).and_return(git_env)

    # Since all blobs are committed to the repository, we mock the gitaly commit
    # client and `object_existence_map` in such way only some of them are considered new.
    allow(repository).to receive(:gitaly_commit_client).and_return(gitaly_commit_client)
    allow(gitaly_commit_client).to receive(:object_existence_map).and_return(object_existence_map)

    # We also want to have the client return the tree entries.
    allow(gitaly_commit_client).to receive(:tree_entries).and_return([tree_entries, gitaly_pagination_cursor])
  end
end

def create_commit(blobs, message = 'Add a file')
  commit = repository.commit_files(
    user,
    branch_name: 'a-new-branch',
    message: message,
    actions: blobs.map do |path, content|
      {
        action: :create,
        file_path: path,
        content: content
      }
    end
  )

  # `list_blobs` only returns unreferenced blobs because it is used for hooks, so we have
  # to delete the branch since Gitaly does not allow us to create loose objects via the RPC.
  repository.delete_branch('a-new-branch')

  commit
end
