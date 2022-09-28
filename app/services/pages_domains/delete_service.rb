# frozen_string_literal: true

module PagesDomains
  class DeleteService < BaseService
    def execute(domain)
      return unless authorized?

      domain.destroy

      publish_event(domain)
    end

    private

    def authorized?
      current_user.can?(:update_pages, project)
    end

    def publish_event(domain)
      event = PagesDomainDeletedEvent.new(
        data: {
          project_id: project.id,
          namespace_id: project.namespace_id,
          root_namespace_id: project.root_namespace.id,
          domain: domain.domain
        }
      )

      Gitlab::EventStore.publish(event)
    end
  end
end
