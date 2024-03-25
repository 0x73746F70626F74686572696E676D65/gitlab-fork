# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::CodeSuggestionsAccessToken, feature_category: :code_suggestions do
  subject { described_class.new(token).as_json }

  let_it_be(:user) { create(:user) }
  let_it_be(:token) { Gitlab::CloudConnector::SelfIssuedToken.new(user, subject: 'ABC-123', scopes: [:code_suggestions]) }

  it 'exposes correct attributes' do
    expect(subject.keys).to contain_exactly(:access_token, :expires_in, :created_at)
  end
end
