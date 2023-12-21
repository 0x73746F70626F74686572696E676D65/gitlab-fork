# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::Teamcity, :use_clean_rails_memory_store_caching do
  include ReactiveCachingHelpers
  include StubRequests

  let(:teamcity_url) { 'https://gitlab.teamcity.com' }
  let(:teamcity_full_url) { 'https://gitlab.teamcity.com/httpAuth/app/rest/builds/branch:unspecified:any,revision:123' }
  let_it_be(:project) { create(:project) }

  subject(:integration) do
    described_class.create!(
      project: project,
      properties: {
        teamcity_url: teamcity_url,
        username: 'mic',
        password: 'password',
        build_type: 'foo'
      }
    )
  end

  it_behaves_like Integrations::BaseCi

  it_behaves_like Integrations::ResetSecretFields

  include_context Integrations::EnableSslVerification do
    describe '#enable_ssl_verification' do
      before do
        allow(integration).to receive(:new_record?).and_return(false)
      end

      it 'returns true for a known hostname' do
        integration.teamcity_url = 'https://example.teamcity.com'

        expect(integration.enable_ssl_verification).to be(true)
      end

      it 'returns true for new records' do
        allow(integration).to receive(:new_record?).and_return(true)
        integration.teamcity_url = 'http://example.com'

        expect(integration.enable_ssl_verification).to be(true)
      end

      it 'returns false for an unknown hostname' do
        integration.teamcity_url = 'https://sub.example.teamcity.com'

        expect(integration.enable_ssl_verification).to be(false)
      end

      it 'returns false for a HTTP URL' do
        integration.teamcity_url = 'http://example.teamcity.com'

        expect(integration.enable_ssl_verification).to be(false)
      end

      it 'returns false for an invalid URL' do
        integration.teamcity_url = 'https://example.com:foo'

        expect(integration.enable_ssl_verification).to be(false)
      end

      it 'returns the persisted value if present' do
        integration.teamcity_url = 'https://example.teamcity.com'
        integration.enable_ssl_verification = false

        expect(integration.enable_ssl_verification).to be(false)
      end
    end
  end

  describe 'Validations' do
    context 'when integration is active' do
      before do
        subject.active = true
      end

      it { is_expected.to validate_presence_of(:build_type) }
      it { is_expected.to validate_presence_of(:teamcity_url) }

      it_behaves_like 'issue tracker integration URL attribute', :teamcity_url

      describe '#username' do
        it 'does not validate the presence of username if password is nil' do
          subject.password = nil

          expect(subject).not_to validate_presence_of(:username)
        end

        it 'validates the presence of username if password is present' do
          subject.password = 'secret'

          expect(subject).to validate_presence_of(:username)
        end
      end

      describe '#password' do
        it 'does not validate the presence of password if username is nil' do
          subject.username = nil

          expect(subject).not_to validate_presence_of(:password)
        end

        it 'validates the presence of password if username is present' do
          subject.username = 'john'

          expect(subject).to validate_presence_of(:password)
        end
      end
    end

    context 'when integration is inactive' do
      before do
        subject.active = false
      end

      it { is_expected.not_to validate_presence_of(:build_type) }
      it { is_expected.not_to validate_presence_of(:teamcity_url) }
      it { is_expected.not_to validate_presence_of(:username) }
      it { is_expected.not_to validate_presence_of(:password) }
    end
  end

  describe '#build_page' do
    it 'returns the contents of the reactive cache' do
      stub_reactive_cache(integration, { build_page: 'foo' }, 'sha', 'ref')

      expect(integration.build_page('sha', 'ref')).to eq('foo')
    end
  end

  describe '#commit_status' do
    it 'returns the contents of the reactive cache' do
      stub_reactive_cache(integration, { commit_status: 'foo' }, 'sha', 'ref')

      expect(integration.commit_status('sha', 'ref')).to eq('foo')
    end
  end

  describe '#calculate_reactive_cache' do
    context 'build_page' do
      subject { integration.calculate_reactive_cache('123', 'unused')[:build_page] }

      it 'returns a specific URL when status is 500' do
        stub_request(status: 500)

        is_expected.to eq("#{teamcity_url}/viewLog.html?buildTypeId=foo")
      end

      it 'returns a build URL when teamcity_url has no trailing slash' do
        stub_request(body: %q({"build":{"id":"666"}}))

        is_expected.to eq("#{teamcity_url}/viewLog.html?buildId=666&buildTypeId=foo")
      end

      context 'teamcity_url has trailing slash' do
        let(:teamcity_url) { 'https://gitlab.teamcity.com/' }

        it 'returns a build URL' do
          stub_request(body: %q({"build":{"id":"666"}}))

          is_expected.to eq('https://gitlab.teamcity.com/viewLog.html?buildId=666&buildTypeId=foo')
        end
      end

      it 'returns the teamcity_url when teamcity is unreachable' do
        stub_full_request(teamcity_full_url).to_raise(Errno::ECONNREFUSED)

        expect(Gitlab::ErrorTracking)
          .to receive(:log_exception)
          .with(instance_of(Errno::ECONNREFUSED), { project_id: project.id })

        is_expected.to eq(teamcity_url)
      end
    end

    context 'commit_status' do
      subject { integration.calculate_reactive_cache('123', 'unused')[:commit_status] }

      it 'sets commit status to :error when status is 500' do
        stub_request(status: 500)

        is_expected.to eq(:error)
      end

      it 'sets commit status to "pending" when status is 404' do
        stub_request(status: 404)

        is_expected.to eq('pending')
      end

      it 'sets commit status to "success" when build status contains SUCCESS' do
        stub_request(build_status: 'YAY SUCCESS!')

        is_expected.to eq('success')
      end

      it 'sets commit status to "failed" when build status contains FAILURE' do
        stub_request(build_status: 'NO FAILURE!')

        is_expected.to eq('failed')
      end

      it 'sets commit status to "pending" when build status contains Pending' do
        stub_request(build_status: 'NO Pending!')

        is_expected.to eq('pending')
      end

      it 'sets commit status to :error when build status is unknown' do
        stub_request(build_status: 'FOO BAR!')

        is_expected.to eq(:error)
      end

      it 'sets commit status to :error when teamcity is unreachable' do
        stub_full_request(teamcity_full_url).to_raise(Errno::ECONNREFUSED)

        expect(Gitlab::ErrorTracking)
          .to receive(:log_exception)
          .with(instance_of(Errno::ECONNREFUSED), { project_id: project.id })

        is_expected.to eq(:error)
      end
    end
  end

  describe '#execute' do
    context 'when push' do
      let(:data) do
        {
          object_kind: 'push',
          ref: 'refs/heads/dev-123_branch',
          after: '0220c11b9a3e6c69dc8fd35321254ca9a7b98f7e',
          total_commits_count: 1
        }
      end

      it 'handles push request correctly' do
        stub_post_to_build_queue(branch: 'dev-123_branch')

        expect(integration.execute(data)).to include('Ok')
      end

      it 'returns nil when ref is blank' do
        data[:after] = Gitlab::Git::SHA1_BLANK_SHA

        expect(integration.execute(data)).to be_nil
      end

      it 'returns nil when there is no content' do
        data[:total_commits_count] = 0

        expect(integration.execute(data)).to be_nil
      end

      it 'returns nil when a merge request is opened for the same ref' do
        create(:merge_request, source_project: project, source_branch: 'dev-123_branch')

        expect(integration.execute(data)).to be_nil
      end
    end

    context 'when merge_request' do
      let(:data) do
        {
          object_kind: 'merge_request',
          ref: 'refs/heads/dev-123_branch',
          after: '0220c11b9a3e6c69dc8fd35321254ca9a7b98f7e',
          total_commits_count: 1,
          object_attributes: {
            state: 'opened',
            source_branch: 'dev-123_branch',
            merge_status: 'unchecked'
          }
        }
      end

      it 'handles merge request correctly' do
        stub_post_to_build_queue(branch: 'dev-123_branch')

        expect(integration.execute(data)).to include('Ok')
      end

      it 'returns nil when merge request is not opened' do
        data[:object_attributes][:state] = 'closed'

        expect(integration.execute(data)).to be_nil
      end

      it 'returns nil unless merge request is marked as unchecked' do
        data[:object_attributes][:merge_status] = 'can_be_merged'

        expect(integration.execute(data)).to be_nil
      end
    end

    it 'returns nil when event is not supported' do
      data = { object_kind: 'foo' }

      expect(integration.execute(data)).to be_nil
    end
  end

  def stub_post_to_build_queue(branch:)
    teamcity_full_url = "#{teamcity_url}/httpAuth/app/rest/buildQueue"
    body ||= %(<build branchName=\"#{branch}\"><buildType id=\"foo\"/></build>)
    auth = %w[mic password]

    stub_full_request(teamcity_full_url, method: :post).with(
      basic_auth: auth,
      body: body,
      headers: {
        'Content-Type' => 'application/xml'
      }
    ).to_return(status: 200, body: 'Ok', headers: {})
  end

  def stub_request(status: 200, body: nil, build_status: 'success')
    auth = %w[mic password]

    body ||= %({"build":{"status":"#{build_status}","id":"666"}})

    stub_full_request(teamcity_full_url).with(basic_auth: auth).to_return(
      status: status,
      headers: { 'Content-Type' => 'application/json' },
      body: body
    )
  end
end
