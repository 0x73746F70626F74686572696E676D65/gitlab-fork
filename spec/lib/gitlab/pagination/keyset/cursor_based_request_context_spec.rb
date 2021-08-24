# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Pagination::Keyset::CursorBasedRequestContext do
  let(:params) { { per_page: 2, cursor: 'eyJuYW1lIjoiR2l0TGFiIEluc3RhbmNlIiwiaWQiOiI1MiIsIl9rZCI6Im4ifQ==' } }
  let(:request) { double('request', params: params) }

  describe '#per_page' do
    subject(:per_page) { described_class.new(request).per_page }

    it { is_expected.to eq 2 }
  end

  describe '#cursor' do
    subject(:cursor) { described_class.new(request).cursor }

    it { is_expected.to eq 'eyJuYW1lIjoiR2l0TGFiIEluc3RhbmNlIiwiaWQiOiI1MiIsIl9rZCI6Im4ifQ==' }
  end

  describe '#apply_headers' do
    let(:request) { double('request', url: "http://#{Gitlab.config.gitlab.host}/api/v4/projects?per_page=3", params: params) }
    let(:params) { { per_page: 3 } }
    let(:cursor_for_next_page) { 'eyJuYW1lIjoiSDVicCIsImlkIjoiMjgiLCJfa2QiOiJuIn0=' }

    subject(:apply_headers) { described_class.new(request).apply_headers(cursor_for_next_page) }

    it 'sets Link header with same host/path as the original request' do
      orig_uri = URI.parse(request.url)

      expect(request).to receive(:header).once do |name, header|
        first_link, _ = /<([^>]+)>; rel="next"/.match(header).captures

        uri = URI.parse(first_link)

        expect(name).to eq('Link')
        expect(uri.host).to eq(orig_uri.host)
        expect(uri.path).to eq(orig_uri.path)
      end

      apply_headers
    end

    it 'sets Link header with a cursor to the next page' do
      orig_uri = URI.parse(request.url)

      expect(request).to receive(:header).once do |name, header|
        first_link, _ = /<([^>]+)>; rel="next"/.match(header).captures

        query = CGI.parse(URI.parse(first_link).query)

        expect(name).to eq('Link')
        expect(query.except('cursor')).to eq(CGI.parse(orig_uri.query).except('cursor'))
        expect(query['cursor']).to eq([cursor_for_next_page])
      end

      apply_headers
    end
  end
end
