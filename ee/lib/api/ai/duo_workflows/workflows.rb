# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      class Workflows < ::API::Base
        include PaginationParams

        feature_category :duo_workflow

        before { authenticate! }

        helpers do
          def find_workflow!(id)
            ::Ai::DuoWorkflows::Workflow.for_user_with_id!(current_user.id, id)
          end

          def authorize_run_workflows!(project)
            return if can?(current_user, :start_duo_workflows, project)

            forbidden!
          end
        end

        namespace :ai do
          namespace :duo_workflows do
            namespace :workflows do
              post do
                project = find_project!(params[:project_id])
                authorize_run_workflows!(project)

                service = ::Ai::DuoWorkflows::CreateWorkflowService.new(project: project, current_user: current_user,
                  params: declared_params(include_missing: false))

                result = service.execute

                bad_request!(result[:message]) if result[:status] == :error

                present result[:workflow], with: ::API::Entities::Ai::DuoWorkflows::Workflow
              end

              get '/:id' do
                workflow = find_workflow!(params[:id])

                present workflow, with: ::API::Entities::Ai::DuoWorkflows::Workflow
              end

              params do
                requires :id, type: Integer, desc: 'The ID of the workflow'
                requires :thread_ts, type: String, desc: 'The thread ts'
                optional :parent_ts, type: String, desc: 'The parent ts'
                requires :checkpoint, type: Hash, desc: "Checkpoint content"
                requires :metadata, type: Hash, desc: "Checkpoint metadata"
              end
              post '/:id/checkpoints' do
                workflow = find_workflow!(params[:id])
                service = ::Ai::DuoWorkflows::CreateCheckpointService.new(project: workflow.project,
                  workflow: workflow, params: declared_params(include_missing: false))
                result = service.execute

                bad_request!(result[:message]) if result[:status] == :error

                present result[:checkpoint], with: ::API::Entities::Ai::DuoWorkflows::Checkpoint
              end

              get '/:id/checkpoints' do
                workflow = find_workflow!(params[:id])
                checkpoints = workflow.checkpoints.order(thread_ts: :desc) # rubocop:disable CodeReuse/ActiveRecord -- adding scope for order is no clearer
                present paginate(checkpoints), with: ::API::Entities::Ai::DuoWorkflows::Checkpoint
              end
            end
          end
        end
      end
    end
  end
end
