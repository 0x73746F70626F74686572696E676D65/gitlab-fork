# frozen_string_literal: true

RSpec.shared_examples 'a compute service handling validation errors' do |client_method:|
  it_behaves_like 'returning an error service response', message: "This is a SaaS-only feature that can't run here"

  context 'with saas only feature enabled' do
    let(:google_cloud_support) { true }

    shared_examples 'logging an error' do |message:|
      it 'logs an error' do
        expect(service).to receive(:log_error)
          .with(class_name: described_class.name, container_id: project.id, message: message)

        subject
      end
    end

    context 'with not enough permissions' do
      let_it_be(:user) { create(:user).tap { |user| project.add_developer(user) } }

      it_behaves_like 'returning an error service response', message: 'Access denied'
    end

    context 'with google_cloud_runner_provisioning FF disabled' do
      before do
        stub_feature_flags(google_cloud_runner_provisioning: false)
      end

      it_behaves_like 'returning an error service response', message: 'Feature flag not enabled'
    end

    context 'with no integration' do
      before do
        wlif_integration.destroy!
      end

      it_behaves_like 'returning an error service response',
        message: 'Google Cloud Identity and Access Management (IAM) project integration not set'
    end

    context 'with disabled integration' do
      before do
        wlif_integration.update!(active: false)
      end

      it_behaves_like 'returning an error service response',
        message: 'Google Cloud Identity and Access Management (IAM) project integration not active'
    end

    context 'when client raises AuthenticationError' do
      before do
        allow(client_double).to receive(client_method).and_raise(::GoogleCloudPlatform::AuthenticationError, 'boom')
      end

      it_behaves_like 'returning an error service response', message: 'Unable to authenticate against Google Cloud'
      it_behaves_like 'logging an error', message: 'boom'
    end

    context 'when client raises ApiError' do
      before do
        allow(client_double).to receive(client_method).and_raise(::GoogleCloudPlatform::ApiError, 'invalid arg')
      end

      it_behaves_like 'returning an error service response',
        message: "#{described_class::GCP_API_ERROR_MESSAGE}: invalid arg"
      it_behaves_like 'logging an error', message: 'invalid arg'
    end
  end
end

RSpec.shared_examples 'overriding the google cloud project id' do
  let(:google_cloud_project_id) { 'project-id-override' }
  let(:extra_params) { { google_cloud_project_id: google_cloud_project_id } }

  it 'returns results by calling the specified project id' do
    expect(::GoogleCloudPlatform::Compute::Client).to receive(:new)
      .with(wlif_integration: wlif_integration, user: user, params: extra_params) do |**args|
        expect(args.dig(:params, :google_cloud_project_id)).to eq(google_cloud_project_id)

        client_double
      end

    expect(response).to be_success
    expect(response.payload[:items]).to be_a Enumerable
    expect(response.payload[:items].count).to be 1
    expect(response.payload[:next_page_token]).to eq('next_page_token')
  end
end
