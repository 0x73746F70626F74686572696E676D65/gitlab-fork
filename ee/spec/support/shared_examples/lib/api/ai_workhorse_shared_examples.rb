# frozen_string_literal: true

RSpec.shared_examples 'behind AI experimentation API feature flag' do
  context 'when ai_experimentation_api is disabled' do
    before do
      stub_feature_flags(ai_experimentation_api: false)
    end

    it 'responds as not found' do
      make_request

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end
end

RSpec.shared_examples 'delegates AI request to Workhorse' do
  it 'responds with Workhorse send-url headers' do
    make_request

    expect(response.body).to eq('""')
    expect(response).to have_gitlab_http_status(:ok)

    send_url_prefix, encoded_data = response.headers['Gitlab-Workhorse-Send-Data'].split(':')
    data = Gitlab::Json.parse(Base64.urlsafe_decode64(encoded_data))

    expect(send_url_prefix).to eq('send-url')
    expect(data).to include({
      'AllowRedirects' => false,
      'Method' => 'POST'
    }.merge(expected_params))
  end
end
