# frozen_string_literal: true

module API
  module Internal
    class UpcomingReconciliations < ::API::Base
      before do
        forbidden!('This API is gitlab.com only!') unless ::Gitlab::CurrentSettings.should_check_namespace_plan?
        authenticated_as_admin!
      end

      feature_category :subscription_management
      urgency :low

      namespace :internal do
        resource :upcoming_reconciliations do
          desc 'Update upcoming reconciliations'
          params do
            requires :upcoming_reconciliations, type: Array[JSON], desc: 'An array of upcoming reconciliations' do
              requires :namespace_id, type: Integer, allow_blank: false
              requires :next_reconciliation_date, type: Date
              requires :display_alert_from, type: Date
            end
          end
          put '/' do
            service = ::UpcomingReconciliations::UpdateService.new(params['upcoming_reconciliations'])
            response = service.execute

            if response.success?
              status 200
            else
              render_api_error!({ error: response.errors.first }, 400)
            end
          end

          desc 'Destroy upcoming reconciliation record'
          params do
            requires :namespace_id, type: Integer, allow_blank: false
          end

          delete '/' do
            upcoming_reconciliation = ::GitlabSubscriptions::UpcomingReconciliation.next(params[:namespace_id])

            not_found! if upcoming_reconciliation.blank?

            upcoming_reconciliation.destroy!

            no_content!
          end
        end

        namespace :gitlab_subscriptions do
          resource 'namespaces/:namespace_id' do
            params do
              requires :namespace_id, type: Integer, allow_blank: false
            end
            resource :upcoming_reconciliations do
              desc 'Update upcoming reconciliations'
              params do
                requires :next_reconciliation_date, type: Date
                requires :display_alert_from, type: Date
              end
              put '/' do
                upcoming_reconciliations = [
                  {
                    namespace_id: params[:namespace_id],
                    next_reconciliation_date: params[:next_reconciliation_date],
                    display_alert_from: params[:display_alert_from]
                  }
                ]
                service = ::UpcomingReconciliations::UpdateService.new(upcoming_reconciliations)
                response = service.execute

                if response.success?
                  status 200
                else
                  render_api_error!({ error: response.errors.first }, 500)
                end
              end

              desc 'Destroy upcoming reconciliation record'
              delete '/' do
                upcoming_reconciliation = ::GitlabSubscriptions::UpcomingReconciliation.next(params[:namespace_id])

                not_found! if upcoming_reconciliation.blank?

                upcoming_reconciliation.destroy!

                no_content!
              end
            end
          end
        end
      end
    end
  end
end
