# frozen_string_literal: true

RSpec.shared_examples 'a harbor tags controller' do |args|
  include HarborHelper
  let_it_be(:user) { create(:user) }
  let_it_be(:unauthorized_user) { create(:user) }
  let_it_be(:json_header) { { accept: 'application/json' } }

  let(:mock_artifacts) do
    [
      {
        artifact_id: 1,
        id: 1,
        immutable: false,
        name: "2",
        pull_time: "0001-01-01T00:00:00.000Z",
        push_time: "2022-04-23T08:04:08.920Z",
        repository_id: 1,
        signed: false
      }
    ]
  end

  let(:repository_id) { 'test' }
  let(:artifact_id) { '1' }

  shared_examples 'responds with 404 status' do
    it 'returns 404' do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'responds with 200 status with json' do
    it 'renders the index template' do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).not_to render_template(:index)
    end
  end

  shared_examples 'responds with 302 status' do
    it 'returns 302' do
      subject

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  shared_examples 'responds with 422 status with json' do
    it 'returns 422' do
      subject

      expect(response).to have_gitlab_http_status(:unprocessable_entity)
    end
  end

  before do
    stub_request(:get,
      "https://demo.goharbor.io/api/v2.0/projects/testproject/repositories/test/artifacts/1/tags"\
      "?page=1&page_size=10")
    .with(
      headers: {
      Authorization: 'Basic aGFyYm9ydXNlcm5hbWU6aGFyYm9ycGFzc3dvcmQ=',
      'Content-Type': 'application/json'
    }).to_return(status: 200, body: mock_artifacts.to_json, headers: { "x-total-count": 2 })
    container.add_reporter(user)
    sign_in(user)
  end

  describe 'GET #index.json' do
    subject do
      get(harbor_tag_url(container, repository_id, artifact_id),
        headers: json_header)
    end

    it_behaves_like 'responds with 200 status with json'

    context 'with anonymous user' do
      before do
        sign_out(user)
      end

      it_behaves_like "responds with #{args[:anonymous_status_code]} status"
    end

    context 'with unauthorized user' do
      before do
        sign_in(unauthorized_user)
      end

      it_behaves_like 'responds with 404 status'
    end

    context 'with valid params' do
      context 'with valid repository' do
        subject do
          get harbor_tag_url(container, repository_id, artifact_id), headers: json_header
        end

        it_behaves_like 'responds with 200 status with json'
      end

      context 'with valid page' do
        subject do
          get(harbor_tag_url(container, repository_id, artifact_id, page: '1'),
            headers: json_header)
        end

        it_behaves_like 'responds with 200 status with json'
      end

      context 'with valid limit' do
        subject do
          get(harbor_tag_url(container, repository_id, artifact_id, limit: '10'),
            headers: json_header)
        end

        it_behaves_like 'responds with 200 status with json'
      end
    end

    context 'with invalid params' do
      context 'with invalid page' do
        subject do
          get(harbor_tag_url(container, repository_id, artifact_id, page: 'aaa'),
            headers: json_header)
        end

        it_behaves_like 'responds with 422 status with json'
      end

      context 'with invalid limit' do
        subject do
          get(harbor_tag_url(container, repository_id, artifact_id, limit: 'aaa'),
            headers: json_header)
        end

        it_behaves_like 'responds with 422 status with json'
      end
    end
  end
end
