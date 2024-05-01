# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Search::Zoekt::Client, :zoekt, :clean_gitlab_redis_cache, feature_category: :global_search do
  let_it_be(:project_1) { create(:project, :public, :repository) }
  let_it_be(:project_2) { create(:project, :public, :repository) }
  let_it_be(:project_3) { create(:project, :public, :repository) }
  let(:client) { described_class.new }

  shared_examples 'an authenticated zoekt request' do
    context 'when basicauth username and password are present' do
      let(:password_file) { Rails.root.join("tmp/tests/zoekt_password") }
      let(:username_file) { Rails.root.join("tmp/tests/zoekt_username") }

      before do
        username_file = Rails.root.join("tmp/tests/zoekt_username")
        File.write(username_file, "the-username\r") # Ensure trailing newline is ignored
        password_file = Rails.root.join("tmp/tests/zoekt_password")
        File.write(password_file, "the-password\r") # Ensure trailing newline is ignored
        stub_config(zoekt: { username_file: username_file, password_file: password_file })
      end

      after do
        File.delete(username_file)
        File.delete(password_file)
      end

      it 'sets those in the request' do
        expect(::Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(basic_auth: { username: 'the-username', password: 'the-password' }))
          .and_call_original

        make_request
      end
    end
  end

  shared_examples 'with relative base_url' do |method|
    let(:base_url) { [zoekt_node.index_base_url, 'nodes', 'zoekt-2'].join('/') }
    let(:custom_node) { create(:zoekt_node, index_base_url: base_url, search_base_url: base_url) }
    let(:body) { {} }
    let(:response) { instance_double(Net::HTTPResponse, body: body.to_json) }
    let(:success) do
      instance_double(HTTParty::Response,
        code: 200, success?: true, parsed_response: body, response: response, body: response.body
      )
    end

    it 'send request to the correct URL' do
      raise 'Unknown method' if %i[delete post].exclude?(method)

      requested_url = custom_node.index_base_url + expected_path
      expect(Gitlab::HTTP).to receive(method).with(requested_url, anything).and_return(success)
      make_request
    end
  end

  shared_examples 'without node backoffs' do |method|
    context 'and an exception occurs' do
      it 'does not backoff current node and exception is still raised' do
        expect(::Search::Zoekt::NodeBackoff).not_to receive(:new)
        expect(::Gitlab::HTTP).to receive(method).and_raise 'boom'
        expect { make_request }.to raise_error 'boom'
      end
    end

    context 'when a backoff is active for zoekt node' do
      it 'does not raise an exception' do
        node.backoff.backoff!

        expect { make_request }.not_to raise_error
      end
    end
  end

  shared_examples 'with node backoffs' do |method|
    before do
      node.backoff.remove_backoff!
    end

    context 'when an exception occurs' do
      it 'backs off current node and re-raises the exception' do
        expect_next_instance_of(::Search::Zoekt::NodeBackoff) do |backoff|
          expect(backoff).to receive(:backoff!)
        end
        expect(::Gitlab::HTTP).to receive(method).and_raise 'boom'
        expect { make_request }.to raise_error 'boom'
      end
    end

    context 'when a backoff is active for zoekt node' do
      it 'raises an exception' do
        node.backoff.backoff!
        expect { make_request }.to raise_error(
          ::Search::Zoekt::Errors::BackoffError, /Zoekt node cannot be used yet because it is in back off period/
        )
      end
    end

    context 'when feature flag zoekt_node_backoffs is disabled' do
      before do
        stub_feature_flags(zoekt_node_backoffs: false)
      end

      it_behaves_like 'without node backoffs', method
    end
  end

  shared_examples 'with connection errors' do |method|
    Gitlab::HTTP::HTTP_ERRORS.each do |error|
      context "when an `#{error}` is raised while trying to connect to zoekt" do
        before do
          allow(::Gitlab::HTTP).to receive(method).and_raise(error)
        end

        it { expect { subject }.to raise_error(::Search::Zoekt::Errors::ClientConnectionError) }
      end
    end

    context 'when an exception is raised during json parsing' do
      before do
        allow(::Gitlab::Json).to receive(:parse).and_raise(Gitlab::Json.parser_error)
      end

      it { expect { subject }.to raise_error(::Search::Zoekt::Errors::ClientConnectionError) }
    end
  end

  describe '#search' do
    let(:project_ids) { [project_1.id, project_2.id] }
    let(:query) { 'use.*egex' }
    let(:node) { ::Search::Zoekt::Node.last }
    let(:node_id) { node.id }
    let(:search_mode) { 'regex' }

    subject(:search) do
      client.search(query, num: 10, project_ids: project_ids, node_id: node_id, search_mode: search_mode)
    end

    before do
      zoekt_ensure_project_indexed!(project_1)
      zoekt_ensure_project_indexed!(project_2)
      zoekt_ensure_project_indexed!(project_3)
    end

    it 'returns the matching files from all searched projects' do
      expect(search.result[:Files].pluck(:FileName)).to include(
        "files/ruby/regex.rb", "files/markdown/ruby-style-guide.md"
      )

      expect(search.result[:Files].map { |r| r[:Repository].to_i }.uniq).to contain_exactly(
        project_1.id, project_2.id
      )
    end

    context 'when there is no project_id filter' do
      let(:project_ids) { [] }

      it 'raises an error if there are somehow no project_id in the filter' do
        expect { search }.to raise_error('Not possible to search without at least one project specified')
      end
    end

    context 'when project_id filter is any' do
      let(:project_ids) { :any }

      it 'raises an error if somehow :any is sent as project_ids' do
        expect { search }.to raise_error('Global search is not supported')
      end
    end

    context 'when search_mode is regex' do
      let(:query) { 'lots code do a' }

      it 'performs regex search and result is not empty' do
        expect(search.result[:Files]).not_to be_nil
      end
    end

    context 'when search_mode is exact' do
      let(:query) { 'lots code do a' }
      let(:search_mode) { 'exact' }

      it 'performs exact search and result is empty' do
        expect(search.result[:Files]).to be_nil
      end
    end

    context 'when search_mode is neither exact nor regex' do
      let(:search_mode) { 'dummy' }

      it 'raises an error' do
        expect { search }.to raise_error(ArgumentError, 'Not a valid search_mode')
      end
    end

    context 'when search_mode is not passed' do
      it 'raises an error' do
        expect { client.search(query, num: 10, project_ids: project_ids, node_id: node_id) }.to raise_error(
          ArgumentError, 'missing keyword: :search_mode')
      end
    end

    context 'with an invalid search' do
      let(:query) { '(invalid search(' }

      it 'logs an error and returns an empty array for results', :aggregate_failures do
        logger = instance_double(::Search::Zoekt::Logger)
        expect(::Search::Zoekt::Logger).to receive(:build).and_return(logger)
        expect(logger).to receive(:error).with(hash_including('status' => 400))

        expect(search.error_message).to include('error parsing regexp')
      end
    end

    it_behaves_like 'an authenticated zoekt request' do
      let(:make_request) { search }
    end

    it_behaves_like 'with relative base_url', :post do
      let(:make_request) { search }
      let(:expected_path) { '/api/search' }
    end

    it_behaves_like 'with node backoffs', :post do
      let(:make_request) { search }
    end

    it_behaves_like 'with connection errors', :post
  end

  describe '#search_multi_node' do
    let(:project_ids) { [project_1.id, project_2.id] }
    let(:query) { 'use.*egex' }
    let(:node) { ::Search::Zoekt::Node.last }
    let(:node_id) { node.id }
    let(:search_mode) { 'regex' }
    let(:targets) { { node_id => project_ids } }

    subject(:search) do
      client.search_multi_node(query, num: 10, targets: targets, search_mode: search_mode)
    end

    before do
      zoekt_ensure_project_indexed!(project_1)
      zoekt_ensure_project_indexed!(project_2)
      zoekt_ensure_project_indexed!(project_3)
    end

    it_behaves_like 'an authenticated zoekt request' do
      let(:make_request) { search }
    end

    it_behaves_like 'with relative base_url', :post do
      let(:make_request) { search }
      let(:expected_path) { '/api/search' }
    end

    context 'when too many targets' do
      let(:targets) { Array.new(described_class::MAXIMUM_THREADS + 1) { |i| [i, i] }.to_h }

      it 'raises an error' do
        expect { search }.to raise_error(/Too many targets/)
      end
    end
  end

  describe '#index' do
    let(:node) { ::Search::Zoekt::Node.last }
    let(:node_id) { node.id }
    let(:successful_response) { true }
    let(:response_body) { {} }
    let(:response) do
      instance_double(HTTParty::Response,
        code: 200,
        success?: successful_response,
        parsed_response: response_body,
        response: instance_double(Net::HTTPResponse, body: response_body.to_json),
        body: response_body.to_json
      )
    end

    subject(:index) { client.index(project_1, node_id) }

    it 'indexes the project to make it searchable' do
      search_results = client.search('use.*egex', num: 10, project_ids: [project_1.id], node_id: node_id,
        search_mode: :regex)
      expect(search_results.result[:Files].to_a.size).to eq(0)

      index

      # Add delay to allow Zoekt wbeserver to finish the indexing
      10.times do
        results = client.search('.*', num: 1, project_ids: [project_1.id], node_id: node_id, search_mode: :regex)
        break if results.result[:FileCount] > 0

        sleep 0.01
      end

      search_results = client.search('use.*egex', num: 10, project_ids: [project_1.id], node_id: node_id,
        search_mode: :regex)
      expect(search_results.result[:Files].to_a.size).to be > 0
    end

    context 'with an error in the response' do
      let(:response_body) { { 'Error' => 'command failed: exit status 128' } }

      it 'raises an exception when indexing errors out' do
        allow(::Gitlab::HTTP).to receive(:post).and_return(response)

        expect { index }.to raise_error(RuntimeError, 'command failed: exit status 128')
      end
    end

    context 'when response code is 429' do
      let(:response) do
        instance_double(HTTParty::Response,
          code: 429, success?: false
        )
      end

      it 'raises an exception when indexing errors out' do
        allow(::Gitlab::HTTP).to receive(:post).and_return(response)

        expect { index }.to raise_error(described_class::TooManyRequestsError)
      end
    end

    context 'with a failed response' do
      let(:successful_response) { false }

      it 'raises an exception when response is not successful' do
        allow(::Gitlab::HTTP).to receive(:post).and_return(response)

        expect { index }.to raise_error(RuntimeError, /Request failed with/)
      end
    end

    it 'sets http the correct timeout' do
      expect(::Gitlab::HTTP).to receive(:post)
                                .with(anything, hash_including(timeout: described_class::INDEXING_TIMEOUT_S))
                                .and_return(response)

      index
    end

    it 'sets force flag' do
      expect(::Gitlab::HTTP).to receive(:post) do |_url, options|
        expect(Gitlab::Json.parse(options[:body], symbolize_keys: true)).to include(Force: true)
      end.and_return(response)

      client.index(project_1, node_id, force: true)
    end

    it 'sets callback body' do
      callback_payload = { foo: 'bar', baz: 'bang', project_id: project_1.id }

      expect(::Gitlab::HTTP).to receive(:post) do |_url, options|
        expect(Gitlab::Json.parse(options[:body],
          symbolize_keys: true)).to include(Callback: { name: 'index', payload: callback_payload })
      end.and_return(response)

      client.index(project_1, node_id, force: true, callback_payload: callback_payload)
    end

    it_behaves_like 'an authenticated zoekt request' do
      let(:make_request) { index }
    end

    it_behaves_like 'with relative base_url', :post do
      let(:make_request) { client.index(project_1, custom_node.id) }
      let(:expected_path) { '/indexer/index' }
    end

    it_behaves_like 'without node backoffs', :post do
      let(:make_request) { index }
    end

    it_behaves_like 'with connection errors', :post
  end

  describe '#delete' do
    let(:node) { zoekt_node }
    let(:node_id) { node.id }

    subject(:delete) { described_class.delete(node_id: node_id, project_id: project_1.id) }

    context 'when project is indexed' do
      before do
        zoekt_ensure_project_indexed!(project_1)
      end

      it 'removes project data from the Zoekt node' do
        search_results = described_class.new.search('use.*egex', num: 10, project_ids: [project_1.id],
          node_id: node_id, search_mode: :regex)
        expect(search_results.result[:Files].to_a.size).to eq(2)

        delete

        # Add delay to allow Zoekt wbeserver to finish the deletion
        10.times do
          results = client.search('.*', num: 1, project_ids: [project_1.id], node_id: node_id, search_mode: :regex)
          break if results.result[:FileCount] == 0

          sleep 0.01
        end

        search_results = described_class.new.search('use.*egex', num: 10, project_ids: [project_1.id],
          node_id: node_id, search_mode: :regex)
        expect(search_results.result[:Files].to_a).to be_empty
      end
    end

    context 'when request fails' do
      let(:response) { {} }

      before do
        zoekt_ensure_project_indexed!(project_1)
        allow(response).to receive(:success?).and_return(false)
        allow(::Gitlab::HTTP).to receive(:delete).and_return(response)
      end

      it 'raises and exception' do
        expect { delete }.to raise_error(StandardError, /Request failed/)
      end
    end

    it_behaves_like 'with relative base_url', :delete do
      let(:make_request) { client.delete(node_id: custom_node.id, project_id: project_1.id) }
      let(:expected_path) { "/indexer/index/#{project_1.id}" }
    end

    it_behaves_like 'without node backoffs', :delete do
      let(:make_request) { delete }
    end

    it_behaves_like 'with connection errors', :delete
  end

  describe '#truncate' do
    let(:zoekt_indexer_truncate_path) { '/indexer/truncate' }
    let(:node) { ::Search::Zoekt::Node.first }

    before do
      zoekt_ensure_project_indexed!(project_1)
      zoekt_ensure_project_indexed!(project_2)
    end

    it 'removes all data from the Zoekt nodes' do
      search_results = client.search('use.*egex', num: 10, project_ids: [project_1.id], node_id: node.id,
        search_mode: :regex)
      expect(search_results.result[:Files].to_a.size).to be > 0
      search_results = client.search('use.*egex', num: 10, project_ids: [project_2.id], node_id: node.id,
        search_mode: :regex)
      expect(search_results.result[:Files].to_a.size).to be > 0

      client.truncate

      # Add delay to allow Zoekt wbeserver to finish the truncation
      project_ids = [project_1, project_2].pluck(:id)
      10.times do
        results = client.search('.*', num: 1, project_ids: project_ids, node_id: node.id, search_mode: :regex)
        break if results.result[:FileCount] == 0

        sleep 0.01
      end

      search_results = client.search('use.*egex', num: 10, project_ids: [project_1.id], node_id: node.id,
        search_mode: :regex)
      expect(search_results.result[:Files].to_a.size).to eq(0)
      search_results = client.search('use.*egex', num: 10, project_ids: [project_2.id], node_id: node.id,
        search_mode: :regex)
      expect(search_results.result[:Files].to_a.size).to eq(0)
    end

    it 'calls post on ::Gitlab::HTTP for all nodes' do
      node2 = create(:zoekt_node)
      zoekt_truncate_path = '/indexer/truncate'
      expect(::Gitlab::HTTP).to receive(:post).with(URI.join(node.index_base_url, zoekt_truncate_path).to_s, anything)
      expect(::Gitlab::HTTP).to receive(:post).with(URI.join(node2.index_base_url, zoekt_truncate_path).to_s, anything)
      client.truncate
    end

    it_behaves_like 'an authenticated zoekt request' do
      let(:make_request) { client.truncate }
    end
  end
end
