# frozen_string_literal: true

module API
  module Internal
    module Search
      class Zoekt < ::API::Base
        before { authenticate_by_gitlab_shell_token! }

        feature_category :global_search
        urgency :medium

        namespace 'internal' do
          namespace 'search' do
            namespace 'zoekt' do
              helpers do
                include Gitlab::Loggable
                def logger
                  @logger ||= ::Search::Zoekt::Logger.build
                end
              end
              route_param :uuid, type: String, desc: 'Indexer node identifier' do
                desc 'Get tasks for a zoekt indexer node' do
                  detail 'This feature was introduced in GitLab 16.5'
                end
                params do
                  requires "node.url", type: String, desc: 'Location where indexer can be reached'
                  requires "disk.all", type: Integer, desc: 'Total disk space'
                  requires "disk.used", type: Integer, desc: 'Total disk space utilized'
                  requires "disk.free", type: Integer, desc: 'Total disk space available'
                  requires "node.name", type: String, desc: 'Name of indexer node'
                end
                get 'tasks' do
                  node = ::Search::Zoekt::Node.find_or_initialize_by_task_request(params)

                  # We don't want to register (save) the node if the feature flag is disabled
                  if Feature.disabled?(:zoekt_internal_api_register_nodes, type: :ops) || node.save
                    { id: node.id }.tap do |resp|
                      if Feature.enabled?(:zoekt_send_tasks)
                        resp[:tasks] = ::Search::Zoekt::TaskPresenterService.execute(node)
                      end
                    end
                  else
                    unprocessable_entity!
                  end
                end

                desc 'Zoekt indexer sends callback logging to Gitlab' do
                  detail 'This feature was introduced in GitLab 16.6'
                end
                params do
                  requires :name, type: String, desc: 'Callback name'
                  requires :success, type: Boolean, desc: 'Set to true if the operation is successful'
                  optional :error, type: String, desc: 'Detailed error message'
                  requires :payload, type: JSON, desc: 'Data payload for the request'
                  optional :additional_payload, type: JSON, desc: 'Additional payload added by the Zoekt indexer'
                end
                post 'callback' do
                  node = ::Search::Zoekt::Node.find_by_uuid(params[:uuid])
                  log_data = {
                    class: 'API::Internal::Search::Zoekt', callback_name: params[:name], payload: params[:payload],
                    additional_payload: params[:additional_payload], success: params[:success],
                    error_message: params[:error]
                  }
                  log_data[:meta] = { 'zoekt.node_name' => node.metadata['name'], 'zoekt.node_id' => node.id } if node
                  log_hash = build_structured_payload(**log_data)
                  params[:success] ? logger.info(log_hash) : logger.error(log_hash)
                  break unprocessable_entity! unless node

                  ::Search::Zoekt::CallbackService.execute(node, params.except(:uuid))
                  accepted!
                end
              end
            end
          end
        end
      end
    end
  end
end
