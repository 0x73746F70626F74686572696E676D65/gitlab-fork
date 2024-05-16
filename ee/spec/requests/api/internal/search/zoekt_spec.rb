# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Search::Zoekt, feature_category: :global_search do
  include GitlabShellHelpers
  include APIInternalBaseHelpers

  describe 'GET /internal/search/zoekt/:uuid/tasks' do
    let(:endpoint) { "/internal/search/zoekt/#{uuid}/tasks" }
    let(:uuid) { '3869fe21-36d1-4612-9676-0b783ef2dcd7' }
    let(:valid_params) do
      {
        'uuid' => uuid,
        'node.url' => 'http://localhost:6090',
        'node.name' => 'm1.local',
        'disk.all' => 994662584320,
        'disk.used' => 532673712128,
        'disk.free' => 461988872192
      }
    end

    context 'with invalid auth' do
      it 'returns 401' do
        get api(endpoint),
          params: valid_params,
          headers: gitlab_shell_internal_api_request_header(issuer: 'gitlab-workhorse')

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'with valid auth' do
      subject(:request) { get api(endpoint), params: valid_params, headers: gitlab_shell_internal_api_request_header }

      context 'with feature flag disabled' do
        before do
          stub_feature_flags(zoekt_internal_api_register_nodes: false)
          allow(::Search::Zoekt::Node).to receive(:find_or_initialize_by_task_request)
            .with(valid_params).and_return(node)
        end

        context 'when node does not exist' do
          let(:node) { build(:zoekt_node, id: nil) }

          it 'does not save node' do
            expect(node).not_to receive(:save)

            request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'id' => nil, 'tasks' => [] })
          end
        end

        context 'when node exists' do
          let(:node) { build(:zoekt_node, id: 123) }

          it 'does not save node when node does not exist' do
            expect(node).not_to receive(:save)

            request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'id' => node.id, 'tasks' => [] })
          end
        end
      end

      context 'when a task request is received with valid params' do
        let(:node) { build(:zoekt_node, id: 123) }
        let(:tasks) { %w[task1 task2] }

        before do
          allow(::Search::Zoekt::TaskPresenterService).to receive(:execute).and_return(tasks)
        end

        it 'returns node ID and tasks for task request' do
          expect(::Search::Zoekt::Node).to receive(:find_or_initialize_by_task_request)
            .with(valid_params).and_return(node)
          expect(node).to receive(:save).and_return(true)

          get api(endpoint), params: valid_params, headers: gitlab_shell_internal_api_request_header

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq({ 'id' => node.id, 'tasks' => tasks })
        end

        context 'when zoekt_send_tasks is disabled' do
          before do
            stub_feature_flags(zoekt_send_tasks: false)
          end

          it 'does not return tasks' do
            expect(::Search::Zoekt::Node).to receive(:find_or_initialize_by_task_request)
              .with(valid_params).and_return(node)
            expect(node).to receive(:save).and_return(true)

            get api(endpoint), params: valid_params, headers: gitlab_shell_internal_api_request_header

            expect(::Search::Zoekt::TaskPresenterService).not_to receive(:execute)
            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'id' => node.id })
          end
        end
      end

      context 'when a heartbeat has valid params but a node validation error occurs' do
        it 'returns 422' do
          node = ::Search::Zoekt::Node.new(search_base_url: nil) # null attributes makes this invalid
          expect(::Search::Zoekt::Node).to receive(:find_or_initialize_by_task_request)
            .with(valid_params).and_return(node)
          get api(endpoint), params: valid_params, headers: gitlab_shell_internal_api_request_header
          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end

      context 'when a heartbeat is received with invalid params' do
        it 'returns 400' do
          get api(endpoint), params: { 'foo' => 'bar' }, headers: gitlab_shell_internal_api_request_header
          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end
  end

  describe 'POST /internal/search/zoekt/:uuid/callback' do
    let_it_be(:project) { create(:project) }
    let(:endpoint) { "/internal/search/zoekt/#{uuid}/callback" }
    let(:uuid) { ::Search::Zoekt::Node.last.uuid }
    let(:logger) { instance_double(::Search::Zoekt::Logger) }
    let(:params) do
      {
        name: 'index',
        success: true,
        payload: { key: 'value' }
      }
    end

    before do
      zoekt_ensure_namespace_indexed!(project.root_namespace)
    end

    context 'with invalid auth' do
      it 'returns 401' do
        post api(endpoint), params: params, headers: gitlab_shell_internal_api_request_header(issuer: 'dummy-workhorse')

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'with valid auth' do
      let(:log_data) do
        {
          class: described_class, callback_name: params[:name], payload: params[:payload], additional_payload: nil,
          success: true, error_message: nil
        }
      end

      context 'when node is found' do
        before do
          allow(::Search::Zoekt::Logger).to receive(:build).and_return(logger)
        end

        context 'and parms success is true' do
          it 'logs the info and returns accepted' do
            node = Search::Zoekt::Node.find_by_uuid(uuid)
            log_data[:meta] = { 'zoekt.node_id' => node.id, 'zoekt.node_name' => node.metadata['name'] }
            expect(logger).to receive(:info).with(log_data.as_json)
            expect(::Search::Zoekt::CallbackService).to receive(:execute).with(node, params)
            post api(endpoint), params: params, headers: gitlab_shell_internal_api_request_header
            expect(response).to have_gitlab_http_status(:accepted)
          end
        end

        context 'and params success is false' do
          it 'logs the error and returns accepted' do
            params.merge!({ success: false, error: 'Message' })
            node = Search::Zoekt::Node.find_by_uuid(uuid)
            log_data_with_meta = log_data.merge(
              {
                success: false, error_message: 'Message',
                meta: { 'zoekt.node_id' => node.id, 'zoekt.node_name' => node.metadata['name'] }
              }
            )
            expect(logger).to receive(:error).with(log_data_with_meta.as_json)
            expect(::Search::Zoekt::CallbackService).to receive(:execute).with(node, params)
            post api(endpoint), params: params, headers: gitlab_shell_internal_api_request_header
            expect(response).to have_gitlab_http_status(:accepted)
          end
        end

        context 'when additional_payload sent in the params' do
          let(:additional_payload) do
            { repo_stats: { index_file_count: 1, size_in_bytes: 1 } }
          end

          it 'log the additional_payload attributes' do
            params[:additional_payload] = additional_payload
            node = Search::Zoekt::Node.find_by_uuid(uuid)
            log_data_with_meta = log_data.merge(
              {
                additional_payload: additional_payload,
                meta: { 'zoekt.node_id' => node.id, 'zoekt.node_name' => node.metadata['name'] }
              }
            )
            expect(logger).to receive(:info).with(log_data_with_meta.as_json)
            expect(::Search::Zoekt::CallbackService).to receive(:execute).with(node, params)
            post api(endpoint), params: params, headers: gitlab_shell_internal_api_request_header, as: :json
            expect(response).to have_gitlab_http_status(:accepted)
          end
        end
      end

      context 'when node is not found' do
        let(:uuid) { 'non_existing' }

        it 'logs the info and returns unprocessable_entity!' do
          allow(::Search::Zoekt::Logger).to receive(:build).and_return(logger)
          expect(logger).to receive(:info).with(log_data.as_json)
          expect(::Search::Zoekt::CallbackService).not_to receive(:execute)
          post api(endpoint), params: params, headers: gitlab_shell_internal_api_request_header
          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end

      context 'when a request is received with invalid params' do
        it 'returns bad_request' do
          expect(::Search::Zoekt::CallbackService).not_to receive(:execute)
          post api(endpoint), params: { 'foo' => 'bar' }, headers: gitlab_shell_internal_api_request_header
          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end
  end
end
