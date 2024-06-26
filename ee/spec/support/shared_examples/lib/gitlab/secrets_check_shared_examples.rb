# frozen_string_literal: true

RSpec.shared_examples 'scan passed' do
  include_context 'secrets check context'

  let(:passed_scan_response) { ::Gitlab::SecretDetection::Response.new(Gitlab::SecretDetection::Status::NOT_FOUND) }
  let(:new_blob_reference) { 'da66bef46dbf0ad7fdcbeec97c9eaa24c2846dda' }
  let(:new_blob) { have_attributes(class: Gitlab::Git::Blob, id: new_blob_reference, size: 24) }

  context 'with quarantine directory' do
    include_context 'quarantine directory exists'

    it 'lists all blobs of a repository' do
      expect(repository).to receive(:list_all_blobs)
        .with(
          bytes_limit: Gitlab::Checks::SecretsCheck::BLOB_BYTES_LIMIT + 1,
          dynamic_timeout: kind_of(Float),
          ignore_alternate_object_directories: true
        )
        .once
        .and_return([old_blob, new_blob])
        .and_call_original

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:secrets_not_found])

      expect { subject.validate! }.not_to raise_error
    end

    it 'filters existing blobs out' do
      expect_next_instance_of(::Gitlab::Checks::ChangedBlobs) do |instance|
        # old blob is expected to be filtered out
        expect(instance).to receive(:filter_existing!)
          .with(
            array_including(old_blob, new_blob)
          )
          .once
          .and_return(new_blob)
          .and_call_original
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:secrets_not_found])

      expect { subject.validate! }.not_to raise_error
    end
  end

  context 'with no quarantine directory' do
    it 'list new blobs' do
      expect(repository).to receive(:list_blobs)
        .with(
          ['--not', '--all', '--not'] + changes.pluck(:newrev),
          bytes_limit: Gitlab::Checks::SecretsCheck::BLOB_BYTES_LIMIT + 1,
          with_paths: false,
          dynamic_timeout: kind_of(Float)
        )
        .once
        .and_return(new_blob)
        .and_call_original

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:secrets_not_found])

      expect { subject.validate! }.not_to raise_error
    end
  end

  it 'scans blobs' do
    expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
      expect(instance).to receive(:secrets_scan)
        .with(
          [new_blob],
          timeout: kind_of(Float)
        )
        .once
        .and_return(passed_scan_response)
        .and_call_original
    end

    expect_next_instance_of(described_class) do |instance|
      expect(instance).to receive(:format_response)
        .with(passed_scan_response)
        .once
        .and_call_original
    end

    expect(secret_detection_logger).to receive(:info)
      .once
      .with(message: log_messages[:secrets_not_found])

    expect { subject.validate! }.not_to raise_error
  end
end

RSpec.shared_examples 'scan detected secrets' do
  include_context 'secrets check context'

  let(:successful_scan_response) do
    ::Gitlab::SecretDetection::Response.new(
      Gitlab::SecretDetection::Status::FOUND,
      [
        Gitlab::SecretDetection::Finding.new(
          new_blob_reference,
          Gitlab::SecretDetection::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "GitLab Personal Access Token"
        )
      ]
    )
  end

  # The new commit must have a secret, so create a commit with one.
  let_it_be(:new_commit) { create_commit('.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB') } # gitleaks:allow

  let(:expected_tree_args) do
    {
      repository: repository, sha: new_commit,
      recursive: true, rescue_not_found: false
    }
  end

  context 'with quarantine directory' do
    include_context 'quarantine directory exists'

    it 'lists all blobs of a repository' do
      expect(repository).to receive(:list_all_blobs)
        .with(
          bytes_limit: Gitlab::Checks::SecretsCheck::BLOB_BYTES_LIMIT + 1,
          dynamic_timeout: kind_of(Float),
          ignore_alternate_object_directories: true
        )
        .once
        .and_return([old_blob, new_blob])
        .and_call_original

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError)
    end

    it 'filters existing blobs out' do
      expect_next_instance_of(::Gitlab::Checks::ChangedBlobs) do |instance|
        # old blob is expected to be filtered out
        expect(instance).to receive(:filter_existing!)
          .with(
            array_including(old_blob, new_blob)
          )
          .once
          .and_return(new_blob)
          .and_call_original
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError)
    end
  end

  context 'with no quarantine directory' do
    it 'list new blobs' do
      expect(repository).to receive(:list_blobs)
        .with(
          ['--not', '--all', '--not'] + changes.pluck(:newrev),
          bytes_limit: Gitlab::Checks::SecretsCheck::BLOB_BYTES_LIMIT + 1,
          with_paths: false,
          dynamic_timeout: kind_of(Float)
        )
        .once
        .and_return(new_blob)
        .and_call_original

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError)
    end
  end

  it 'scans blobs' do
    expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
      expect(instance).to receive(:secrets_scan)
        .with(
          [new_blob],
          timeout: kind_of(Float)
        )
        .once
        .and_return(successful_scan_response)
        .and_call_original
    end

    expect(secret_detection_logger).to receive(:info)
      .once
      .with(message: log_messages[:found_secrets])

    expect { subject.validate! }.to raise_error do |error|
      expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
      expect(error.message).to include(
        log_messages[:found_secrets],
        finding_message_header,
        finding_message_path,
        finding_message_occurrence_line,
        log_messages[:found_secrets_post_message],
        found_secrets_docs_link
      )
    end
  end

  it 'loads tree entries of the new commit' do
    expect(::Gitlab::Git::Tree).to receive(:tree_entries)
      .once
      .with(**expected_tree_args)
      .and_return([tree_entries, gitaly_pagination_cursor])
      .and_call_original

    expect(secret_detection_logger).to receive(:info)
      .once
      .with(message: log_messages[:found_secrets])

    expect { subject.validate! }.to raise_error do |error|
      expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
      expect(error.message).to include(
        log_messages[:found_secrets],
        finding_message_header,
        finding_message_path,
        finding_message_occurrence_line,
        log_messages[:found_secrets_post_message],
        found_secrets_docs_link
      )
    end
  end

  context 'when no tree entries exist or cannot be loaded' do
    it 'gracefully raises an error with existing information' do
      expect(::Gitlab::Git::Tree).to receive(:tree_entries)
        .once
        .with(**expected_tree_args)
        .and_return([{}, gitaly_pagination_cursor])

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message_with_blob,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end

  context 'when tree has too many entries' do
    let(:gitaly_pagination_cursor) { Gitaly::PaginationCursor.new(next_cursor: "abcdef") }

    it 'logs an error and continue to raise and present findings' do
      expect(::Gitlab::Git::Tree).to receive(:tree_entries)
        .once
        .with(**expected_tree_args)
        .and_return([tree_entries, gitaly_pagination_cursor])

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect(secret_detection_logger).to receive(:error)
        .once
        .with(message: too_many_tree_entries_error)

      expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError)
    end
  end

  context 'when new commit has file in subdirectory' do
    let_it_be(:new_commit) { create_commit('config/.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB') } # gitleaks:allow

    let(:finding_path) { 'config/.env' }
    let(:tree_entries) do
      [
        Gitlab::Git::Tree.new(
          id: new_blob_reference,
          type: :blob,
          mode: '100644',
          name: '.env',
          path: 'config/.env',
          flat_path: 'config/.env',
          commit_id: new_commit
        )
      ]
    end

    it 'loads tree entries of the new commit in subdirectories' do
      expect(::Gitlab::Git::Tree).to receive(:tree_entries)
        .once
        .with(**expected_tree_args)
        .and_return([tree_entries, gitaly_pagination_cursor])
        .and_call_original

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message_header,
          finding_message_path,
          finding_message_occurrence_line,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end

  context 'when a blob has multiple secrets' do
    let_it_be(:new_commit) do
      create_commit('.env' => "SECRET=glpat-JUST20LETTERSANDNUMB\nTOKEN=glpat-JUST20LETTERSANDNUMB") # gitleaks:allow
    end

    let(:new_blob_reference) { '59ef300b246861163ee1e2ab4146e16144e4770f' }
    let(:new_blob) { have_attributes(class: Gitlab::Git::Blob, id: new_blob_reference, size: 66) }

    let(:successful_with_multiple_findings_scan_response) do
      ::Gitlab::SecretDetection::Response.new(
        Gitlab::SecretDetection::Status::FOUND,
        [
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          ),
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            2,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          )
        ]
      )
    end

    it 'displays all findings with their corresponding commit sha/filepath' do
      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            [new_blob],
            timeout: kind_of(Float)
          )
          .once
          .and_return(successful_with_multiple_findings_scan_response)
          .and_call_original
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message_header,
          finding_message_multiple_occurrence_lines,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end

  context 'when a blob is present in multiple commits' do
    let_it_be(:new_commit) do
      create_commit('.env' => "SECRET=glpat-JUST20LETTERSANDNUMB") # gitleaks:allow
    end

    let_it_be(:commit_with_same_blob) do
      create_commit(
        { '.env' => "SECRET=glpat-JUST20LETTERSANDNUMB" }, # gitleaks:allow
        'Same commit different message'
      )
    end

    let(:new_blob_reference) { 'fe29d93da4843da433e62711ace82db601eb4f8f' }
    let(:new_blob) { have_attributes(class: Gitlab::Git::Blob, id: new_blob_reference, size: 33) }

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
        ),
        Gitlab::Git::Tree.new(
          id: new_blob_reference,
          type: :blob,
          mode: '100644',
          name: '.env',
          path: '.env',
          flat_path: '.env',
          commit_id: commit_with_same_blob
        )
      ]
    end

    let(:changes) do
      [
        { oldrev: initial_commit, newrev: new_commit, ref: 'refs/heads/master' },
        { oldrev: initial_commit, newrev: commit_with_same_blob, ref: 'refs/heads/master' }
      ]
    end

    let(:successful_with_same_blob_in_multiple_commits_scan_response) do
      ::Gitlab::SecretDetection::Response.new(
        Gitlab::SecretDetection::Status::FOUND,
        [
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          ),
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          )
        ]
      )
    end

    it 'displays the findings with their corresponding commit sha/file path' do
      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            [new_blob],
            timeout: kind_of(Float)
          )
          .once
          .and_return(successful_with_same_blob_in_multiple_commits_scan_response)
          .and_call_original
      end

      expect(::Gitlab::Git::Tree).to receive(:tree_entries)
        .with(**expected_tree_args.merge(sha: new_commit))
        .once
        .and_return([tree_entries, gitaly_pagination_cursor])
        .and_call_original

      expect(::Gitlab::Git::Tree).to receive(:tree_entries)
        .with(**expected_tree_args.merge(sha: commit_with_same_blob))
        .once
        .and_return([tree_entries, gitaly_pagination_cursor])
        .and_call_original

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message_same_blob_in_multiple_commits_header_path_and_lines,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end

  context 'when a blob has multiple secrets on the same line' do
    let_it_be(:new_commit) do
      create_commit('.env' => "SECRET=glpat-JUST20LETTERSANDNUMB;TOKEN=GR1348941JUST20LETTERSANDNUMB") # gitleaks:allow)
    end

    let(:new_blob_reference) { '13a31e7c93bbe8781f341e24e8ef26ef717d0da2' }
    let(:new_blob) { have_attributes(class: Gitlab::Git::Blob, id: new_blob_reference, size: 69) }

    let(:second_finding_description) { 'GitLab Runner Registration Token' }

    let(:successful_with_multiple_findings_on_same_line_scan_response) do
      ::Gitlab::SecretDetection::Response.new(
        Gitlab::SecretDetection::Status::FOUND,
        [
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          ),
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_runner_registration_token",
            "GitLab Runner Registration Token"
          )
        ]
      )
    end

    it 'displays the findings with their corresponding commit sha/filepath' do
      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            [new_blob],
            timeout: kind_of(Float)
          )
          .once
          .and_return(successful_with_multiple_findings_on_same_line_scan_response)
          .and_call_original
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message_header,
          finding_message_multiple_findings_on_same_line,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end

  context 'when multiple blobs contain secrets in a commit' do
    let_it_be(:new_commit) do
      create_commit('.env' => "SECRET=glpat-JUST20LETTERSANDNUMB", # gitleaks:allow
        'test.txt' => "SECRET=glrt-JUST20LETTERSANDNUMB") # gitleaks:allow
    end

    let(:new_blob_reference2) { '5f571267577ed6e0b4b24fb87f7a8218d5912eb9' }
    let(:new_blob) { have_attributes(class: Gitlab::Git::Blob, id: new_blob_reference, size: 33) }
    let(:new_blob2) { have_attributes(class: Gitlab::Git::Blob, id: new_blob_reference2, size: 32) }

    let(:successful_with_multiple_files_findings_scan_response) do
      ::Gitlab::SecretDetection::Response.new(
        Gitlab::SecretDetection::Status::FOUND,
        [
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          ),
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference2,
            Gitlab::SecretDetection::Status::FOUND,
            2,
            "gitlab_runner_authentication_token",
            "GitLab Runner Authentication Token"
          )
        ]
      )
    end

    it 'displays all findings with their corresponding commit sha/filepath' do
      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            array_including(new_blob, new_blob2),
            timeout: kind_of(Float)
          )
          .once.and_call_original do |*args|
            expect(instance.secrets_scan(*args)).to eq(successful_with_multiple_files_findings_scan_response)
          end
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message_header,
          finding_message_path,
          finding_message_multiple_files_occurrence_lines,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end
end

RSpec.shared_examples 'scan detected secrets but some errors occured' do
  include_context 'secrets check context'

  let(:successful_scan_with_errors_response) do
    ::Gitlab::SecretDetection::Response.new(
      Gitlab::SecretDetection::Status::FOUND_WITH_ERRORS,
      [
        Gitlab::SecretDetection::Finding.new(
          new_blob_reference,
          Gitlab::SecretDetection::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "GitLab Personal Access Token"
        ),
        Gitlab::SecretDetection::Finding.new(
          timed_out_blob_reference,
          Gitlab::SecretDetection::Status::BLOB_TIMEOUT
        ),
        Gitlab::SecretDetection::Finding.new(
          failed_to_scan_blob_reference,
          Gitlab::SecretDetection::Status::SCAN_ERROR
        )
      ]
    )
  end

  let_it_be(:new_commit) { create_commit('.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB') } # gitleaks:allow
  let_it_be(:timed_out_commit) { create_commit('.test.env' => 'TOKEN=glpat-JUST20LETTERSANDNUMB') } # gitleaks:allow
  let_it_be(:failed_to_scan_commit) { create_commit('.dev.env' => 'GLPAT=glpat-JUST20LETTERSANDNUMB') } # gitleaks:allow

  let(:expected_tree_args) do
    { repository: repository, recursive: true, rescue_not_found: false }
  end

  let(:changes) do
    [
      { oldrev: initial_commit, newrev: new_commit, ref: 'refs/heads/master' },
      { oldrev: initial_commit, newrev: timed_out_commit, ref: 'refs/heads/master' },
      { oldrev: initial_commit, newrev: failed_to_scan_commit, ref: 'refs/heads/master' }
    ]
  end

  let(:timed_out_blob_reference) { 'eaf3c09526f50b5e35a096ef70cca033f9974653' }
  let(:failed_to_scan_blob_reference) { '4fbec77313fd240d00fc37e522d0274b8fb54bd1' }

  let(:timed_out_blob) { have_attributes(class: Gitlab::Git::Blob, id: timed_out_blob_reference, size: 32) }
  let(:failed_to_scan_blob) { have_attributes(class: Gitlab::Git::Blob, id: failed_to_scan_blob_reference, size: 32) }

  # Used for the quarantine directory context below.
  let(:object_existence_map) do
    {
      old_blob_reference.to_s => true,
      new_blob_reference.to_s => false,
      timed_out_blob_reference.to_s => false,
      failed_to_scan_blob_reference.to_s => false
    }
  end

  context 'with quarantine directory' do
    include_context 'quarantine directory exists'

    it 'lists all blobs of a repository' do
      expect(repository).to receive(:list_all_blobs)
        .with(
          bytes_limit: Gitlab::Checks::SecretsCheck::BLOB_BYTES_LIMIT + 1,
          dynamic_timeout: kind_of(Float),
          ignore_alternate_object_directories: true
        )
        .once
        .and_return(
          [old_blob, new_blob, timed_out_blob, failed_to_scan_blob]
        )
        .and_call_original

      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            array_including(new_blob, timed_out_blob, failed_to_scan_blob),
            timeout: kind_of(Float)
          )
          .and_return(successful_scan_with_errors_response)
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets_with_errors])

      expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError)
    end

    it 'filters existing blobs out' do
      expect_next_instance_of(::Gitlab::Checks::ChangedBlobs) do |instance|
        # old blob is expected to be filtered out
        expect(instance).to receive(:filter_existing!)
          .with(
            array_including(old_blob, new_blob, timed_out_blob, failed_to_scan_blob)
          )
          .once
          .and_return(
            array_including(new_blob, timed_out_blob, failed_to_scan_blob)
          )
          .and_call_original
      end

      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            array_including(new_blob, timed_out_blob, failed_to_scan_blob),
            timeout: kind_of(Float)
          )
          .and_return(successful_scan_with_errors_response)
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets_with_errors])

      expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError)
    end
  end

  context 'with no quarantine directory' do
    it 'list new blobs' do
      expect(repository).to receive(:list_blobs)
        .with(
          ['--not', '--all', '--not'] + changes.pluck(:newrev),
          bytes_limit: Gitlab::Checks::SecretsCheck::BLOB_BYTES_LIMIT + 1,
          with_paths: false,
          dynamic_timeout: kind_of(Float)
        )
        .once
        .and_return(
          array_including(new_blob, old_blob, timed_out_blob, failed_to_scan_blob)
        )
        .and_call_original

      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            array_including(new_blob, timed_out_blob, failed_to_scan_blob),
            timeout: kind_of(Float)
          )
          .and_return(successful_scan_with_errors_response)
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets_with_errors])

      expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError)
    end
  end

  it 'scans blobs' do
    expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
      expect(instance).to receive(:secrets_scan)
        .with(
          array_including(new_blob, timed_out_blob, failed_to_scan_blob),
          timeout: kind_of(Float)
        )
        .once
        .and_return(successful_scan_with_errors_response)
    end

    expect_next_instance_of(described_class) do |instance|
      expect(instance).to receive(:format_response)
      .with(successful_scan_with_errors_response)
      .once
      .and_call_original
    end

    expect(secret_detection_logger).to receive(:info)
      .once
      .with(message: log_messages[:found_secrets_with_errors])

    expect { subject.validate! }.to raise_error do |error|
      expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
      expect(error.message).to include(
        log_messages[:found_secrets_with_errors],
        finding_message_header,
        finding_message_path,
        finding_message_occurrence_line,
        blob_timed_out_error,
        failed_to_scan_regex_error,
        log_messages[:found_secrets_post_message],
        found_secrets_docs_link
      )
    end
  end

  it 'loads tree entries of the new commit' do
    expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
      expect(instance).to receive(:secrets_scan)
        .with(
          array_including(new_blob, timed_out_blob, failed_to_scan_blob),
          timeout: kind_of(Float)
        )
        .once
        .and_return(successful_scan_with_errors_response)
    end

    expect(::Gitlab::Git::Tree).to receive(:tree_entries)
      .with(**expected_tree_args.merge(sha: new_commit))
      .once
      .and_return([tree_entries, gitaly_pagination_cursor])
      .and_call_original

    expect(::Gitlab::Git::Tree).to receive(:tree_entries)
      .with(**expected_tree_args.merge(sha: timed_out_commit))
      .once
      .and_return([[], nil])
      .and_call_original

    expect(::Gitlab::Git::Tree).to receive(:tree_entries)
      .with(**expected_tree_args.merge(sha: failed_to_scan_commit))
      .once
      .and_return([[], nil])
      .and_call_original

    expect(secret_detection_logger).to receive(:info)
      .once
      .with(message: log_messages[:found_secrets_with_errors])

    expect { subject.validate! }.to raise_error do |error|
      expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
      expect(error.message).to include(
        log_messages[:found_secrets_with_errors],
        finding_message_header,
        finding_message_path,
        finding_message_occurrence_line,
        blob_timed_out_error,
        failed_to_scan_regex_error,
        log_messages[:found_secrets_post_message],
        found_secrets_docs_link
      )
    end
  end

  context 'when a blob has multiple secrets' do
    let_it_be(:new_commit) do
      create_commit('.env' => "SECRET=glpat-JUST20LETTERSANDNUMB\nTOKEN=glpat-JUST20LETTERSANDNUMB") # gitleaks:allow
    end

    let(:new_blob_reference) { '59ef300b246861163ee1e2ab4146e16144e4770f' }
    let(:new_blob) { have_attributes(class: Gitlab::Git::Blob, id: new_blob_reference, size: 66) }

    let(:successful_scan_with_multiple_findings_and_errors_response) do
      ::Gitlab::SecretDetection::Response.new(
        Gitlab::SecretDetection::Status::FOUND_WITH_ERRORS,
        [
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          ),
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            2,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          ),
          Gitlab::SecretDetection::Finding.new(
            timed_out_blob_reference,
            Gitlab::SecretDetection::Status::BLOB_TIMEOUT
          ),
          Gitlab::SecretDetection::Finding.new(
            failed_to_scan_blob_reference,
            Gitlab::SecretDetection::Status::SCAN_ERROR
          )
        ]
      )
    end

    it 'displays all findings with their corresponding commit sha/filepath' do
      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            array_including(new_blob, timed_out_blob, failed_to_scan_blob),
            timeout: kind_of(Float)
          )
          .once
          .and_return(successful_scan_with_multiple_findings_and_errors_response)
      end

      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:format_response)
          .with(successful_scan_with_multiple_findings_and_errors_response)
          .once
          .and_call_original
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets_with_errors])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets_with_errors],
          finding_message_header,
          finding_message_multiple_occurrence_lines,
          blob_timed_out_error,
          failed_to_scan_regex_error,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end
end

RSpec.shared_examples 'scan timed out' do
  include_context 'secrets check context'

  let(:scan_timed_out_scan_response) do
    ::Gitlab::SecretDetection::Response.new(Gitlab::SecretDetection::Status::SCAN_TIMEOUT)
  end

  it 'logs the error and passes the check' do
    # Mock the response to return a scan timed out status.
    expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
      expect(instance).to receive(:secrets_scan)
        .and_return(scan_timed_out_scan_response)
    end

    # Error bubbles up from scan class and is handled in secrets check.
    expect(secret_detection_logger).to receive(:error)
      .once
      .with(message: error_messages[:scan_timeout_error])

    expect { subject.validate! }.not_to raise_error
  end
end

RSpec.shared_examples 'scan failed to initialize' do
  include_context 'secrets check context'

  before do
    # Intentionally set `RULESET_FILE_PATH` to an incorrect path to cause error.
    stub_const('::Gitlab::SecretDetection::Scan::RULESET_FILE_PATH', 'gitleaks.toml')
  end

  it 'logs the error and passes the check' do
    # File parsing error is written to the logger.
    expect(secret_detection_logger).to receive(:error)
      .once
      .with(
        "Failed to parse secret detection ruleset from 'gitleaks.toml' path: " \
        "No such file or directory @ rb_sysopen - gitleaks.toml"
      )

    # Error bubbles up from scan class and is handled in secrets check.
    expect(secret_detection_logger).to receive(:error)
      .once
      .with(message: error_messages[:scan_initialization_error])

    expect { subject.validate! }.not_to raise_error
  end
end

RSpec.shared_examples 'scan failed with invalid input' do
  include_context 'secrets check context'

  let(:failed_with_invalid_input_response) do
    ::Gitlab::SecretDetection::Response.new(::Gitlab::SecretDetection::Status::INPUT_ERROR)
  end

  it 'logs the error and passes the check' do
    # Mock the response to return a scan invalid input status.
    expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
      expect(instance).to receive(:secrets_scan)
        .and_return(failed_with_invalid_input_response)
    end

    # Error bubbles up from scan class and is handled in secrets check.
    expect(secret_detection_logger).to receive(:error)
      .once
      .with(message: error_messages[:invalid_input_error])

    expect { subject.validate! }.not_to raise_error
  end
end

RSpec.shared_examples 'scan skipped due to invalid status' do
  include_context 'secrets check context'

  let(:invalid_scan_status_code) { 7 } # doesn't exist in ::Gitlab::SecretDetection::Status
  let(:invalid_scan_status_code_response) { ::Gitlab::SecretDetection::Response.new(invalid_scan_status_code) }

  it 'logs the error and passes the check' do
    # Mock the response to return a scan invalid status.
    expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
      expect(instance).to receive(:secrets_scan)
        .and_return(invalid_scan_status_code_response)
    end

    # Error bubbles up from scan class and is handled in secrets check.
    expect(secret_detection_logger).to receive(:error)
      .once
      .with(message: error_messages[:invalid_scan_status_code_error])

    expect { subject.validate! }.not_to raise_error
  end
end

RSpec.shared_examples 'scan skipped when a commit has special bypass flag' do
  include_context 'secrets check context'

  let_it_be(:new_commit) do
    create_commit(
      { '.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB' }, # gitleaks:allow
      'dummy commit [skip secret detection]'
    )
  end

  it 'skips the scanning process' do
    expect { subject.validate! }.not_to raise_error
  end

  context 'when other commits have secrets in the same push' do
    let_it_be(:second_commit_with_secret) do
      create_commit('.test.env' => 'TOKEN=glpat-JUST20LETTERSANDNUMB') # gitleaks:allow
    end

    let(:changes) do
      [
        { oldrev: initial_commit, newrev: new_commit, ref: 'refs/heads/master' },
        { oldrev: initial_commit, newrev: second_commit_with_secret, ref: 'refs/heads/master' }
      ]
    end

    it 'skips the scanning process still' do
      expect { subject.validate! }.not_to raise_error
    end
  end

  it 'creates an audit event' do
    expect { subject.validate! }.to change { AuditEvent.count }.by(1)
    expect(AuditEvent.last.details[:custom_message]).to eq("Secret push protection skipped via commit message")
  end

  it_behaves_like 'internal event tracking' do
    let(:event) { 'skip_secret_push_protection' }
    let(:namespace) { project.namespace }
    let(:label) { "commit message" }
    let(:category) { described_class.name }
    subject { super().validate! }
  end
end

RSpec.shared_examples 'scan skipped when secret_detection.skip_all push option is passed' do
  include_context 'secrets check context'

  let(:changes_access) do
    Gitlab::Checks::ChangesAccess.new(
      changes,
      project: project,
      user_access: user_access,
      protocol: protocol,
      logger: logger,
      push_options: Gitlab::PushOptions.new(["secret_detection.skip_all"])
    )
  end

  let_it_be(:new_commit) do
    create_commit(
      { '.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB' } # gitleaks:allow
    )
  end

  it 'skips the scanning process' do
    expect { subject.validate! }.not_to raise_error
  end

  context 'when other commits have secrets in the same push' do
    let_it_be(:second_commit_with_secret) do
      create_commit('.test.env' => 'TOKEN=glpat-JUST20LETTERSANDNUMB') # gitleaks:allow
    end

    let(:changes) do
      [
        { oldrev: initial_commit, newrev: new_commit, ref: 'refs/heads/master' },
        { oldrev: initial_commit, newrev: second_commit_with_secret, ref: 'refs/heads/master' }
      ]
    end

    it 'skips the scanning process still' do
      expect { subject.validate! }.not_to raise_error
    end
  end

  it 'creates an audit event' do
    expect { subject.validate! }.to change { AuditEvent.count }.by(1)
    expect(AuditEvent.last.details[:custom_message]).to eq("Secret push protection skipped via push option")
  end

  it_behaves_like 'internal event tracking' do
    let(:event) { 'skip_secret_push_protection' }
    let(:namespace) { project.namespace }
    let(:label) { "push option" }
    let(:category) { described_class.name }
    subject { super().validate! }
  end
end
