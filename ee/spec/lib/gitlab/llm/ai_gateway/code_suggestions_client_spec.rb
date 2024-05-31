# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::CodeSuggestionsClient, feature_category: :code_suggestions do
  let_it_be(:user) { create(:user) }

  describe "#test_completion" do
    let_it_be(:token) { create(:service_access_token, :active) }
    let(:body) { { choices: [{ text: "puts \"Hello World!\"\nend", index: 0, finish_reason: "length" }] } }
    let(:code) { 200 }

    subject(:result) { described_class.new(user).test_completion }

    shared_examples "error response" do |message|
      it "returns an error" do
        expect(result).to eq(message)
      end
    end

    before do
      stub_request(:post, /#{Gitlab::AiGateway.url}/)
        .to_return(status: code, body: body.to_json, headers: { "Content-Type" => "application/json" })
      allow(CloudConnector::AvailableServices).to receive_message_chain(:find_by_name,
        :access_token).and_return(token)
    end

    it 'returns nil if there is no error' do
      expect(result).to be_nil
    end

    context 'when there is not valid token' do
      let(:token) { nil }

      it_behaves_like 'error response', "Access token is missing"
    end

    context 'when response does not contain a valid choice' do
      let(:body) { { choices: [] } }

      it_behaves_like 'error response', "Response doesn't contain a completion"
    end

    context 'when response code is not 200' do
      let(:code) { 401 }
      let(:body) { 'an error' }

      it_behaves_like 'error response', 'AI Gateway returned code 401: "an error"'
    end

    context 'when request raises an error' do
      before do
        stub_request(:post, /#{Gitlab::AiGateway.url}/).to_raise(StandardError.new('an error'))
      end

      it_behaves_like 'error response', 'an error'
    end
  end
end
