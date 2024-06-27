# frozen_string_literal: true

module EE
  module Gitlab
    module EventStore
      extend ActiveSupport::Concern

      class_methods do
        extend ::Gitlab::Utils::Override
        # Define event subscriptions using:
        #
        #   store.subscribe(DomainA::SomeWorker, to: DomainB::SomeEvent)
        #
        # It is possible to subscribe to a subset of events matching a condition:
        #
        #   store.subscribe(DomainA::SomeWorker, to: DomainB::SomeEvent), if: ->(event) { event.data == :some_value }
        #
        # Only EE subscriptions should be declared in this module.
        override :configure!
        def configure!(store)
          super(store)

          ###
          # Add EE only subscriptions here:

          store.subscribe ::Security::Scans::PurgeByJobIdWorker, to: ::Ci::JobArtifactsDeletedEvent
          store.subscribe ::Geo::CreateRepositoryUpdatedEventWorker,
            to: ::Repositories::KeepAroundRefsCreatedEvent,
            if: ->(_) { ::Gitlab::Geo.primary? }
          store.subscribe ::MergeRequests::StreamApprovalAuditEventWorker, to: ::MergeRequests::ApprovedEvent
          store.subscribe ::MergeRequests::CreateApprovalsResetNoteWorker, to: ::MergeRequests::ApprovalsResetEvent
          store.subscribe ::PullMirrors::ReenableConfigurationWorker, to: ::GitlabSubscriptions::RenewedEvent
          store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker,
            to: ::MergeRequests::ExternalStatusCheckPassedEvent
          store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker, to: ::MergeRequests::UnblockedStateEvent
          store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker,
            to: ::MergeRequests::JiraTitleDescriptionUpdateEvent
          store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker,
            to: ::MergeRequests::OverrideRequestedChangesStateEvent
          store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker, to: ::MergeRequests::ApprovedEvent
          store.subscribe ::Search::ElasticDefaultBranchChangedWorker,
            to: ::Repositories::DefaultBranchChangedEvent,
            if: ->(_) { ::Gitlab::CurrentSettings.elasticsearch_indexing? }
          store.subscribe ::Search::Zoekt::DefaultBranchChangedWorker, to: ::Repositories::DefaultBranchChangedEvent
          store.subscribe ::PackageMetadata::GlobalAdvisoryScanWorker, to: ::PackageMetadata::IngestedAdvisoryEvent
          store.subscribe ::Llm::NamespaceAccessCacheResetWorker, to: ::NamespaceSettings::AiRelatedSettingsChangedEvent
          store.subscribe ::Llm::NamespaceAccessCacheResetWorker, to: ::Members::MembersAddedEvent
          store.subscribe ::Security::RefreshProjectPoliciesWorker,
            to: ::ProjectAuthorizations::AuthorizationsChangedEvent,
            delay: 1.minute
          store.subscribe ::MergeRequests::RemoveUserApprovalRulesWorker,
            to: ::ProjectAuthorizations::AuthorizationsRemovedEvent
          store.subscribe ::Security::ScanResultPolicies::AddApproversToRulesWorker,
            to: ::ProjectAuthorizations::AuthorizationsAddedEvent
          store.subscribe ::Security::RefreshComplianceFrameworkSecurityPoliciesWorker,
            to: ::Projects::ComplianceFrameworkChangedEvent
          store.subscribe ::AppSec::ContainerScanning::ScanImageWorker,
            to: ::ContainerRegistry::ImagePushedEvent,
            delay: 1.minute,
            if: ->(event) { ::AppSec::ContainerScanning::ScanImageWorker.dispatch?(event) }

          register_threat_insights_subscribers(store)

          subscribe_to_epic_events(store)
          subscribe_to_external_issue_links_events(store)
          subscribe_to_work_item_events(store)
          subscribe_to_milestone_events(store)
        end

        def register_threat_insights_subscribers(store)
          store.subscribe ::Sbom::ProcessTransferEventsWorker, to: ::Projects::ProjectTransferedEvent
          store.subscribe ::Sbom::ProcessTransferEventsWorker, to: ::Groups::GroupTransferedEvent
          store.subscribe ::Sbom::SyncArchivedStatusWorker, to: ::Projects::ProjectArchivedEvent

          store.subscribe ::Vulnerabilities::ProcessTransferEventsWorker, to: ::Projects::ProjectTransferedEvent
          store.subscribe ::Vulnerabilities::ProcessTransferEventsWorker, to: ::Groups::GroupTransferedEvent
          store.subscribe ::Vulnerabilities::ProcessArchivedEventsWorker, to: ::Projects::ProjectArchivedEvent
        end

        def subscribe_to_epic_events(store)
          store.subscribe ::WorkItems::ValidateEpicWorkItemSyncWorker,
            to: ::Epics::EpicCreatedEvent,
            if: ->(event) {
              ::Feature.enabled?(:validate_epic_work_item_sync, ::Group.actor_from_id(event.data[:group_id]))
            }
          store.subscribe ::WorkItems::ValidateEpicWorkItemSyncWorker,
            to: ::Epics::EpicUpdatedEvent,
            if: ->(event) {
              ::Feature.enabled?(:validate_epic_work_item_sync, ::Group.actor_from_id(event.data[:group_id]))
            }
        end

        def subscribe_to_external_issue_links_events(store)
          store.subscribe ::VulnerabilityExternalIssueLinks::UpdateVulnerabilityRead,
            to: ::Vulnerabilities::LinkToExternalIssueTrackerCreated,
            if: ->(event) {
                  ::Feature.enabled?(:handle_vulnerability_external_issue_link_via_events, event.project)
                }

          store.subscribe ::VulnerabilityExternalIssueLinks::UpdateVulnerabilityRead,
            to: ::Vulnerabilities::LinkToExternalIssueTrackerRemoved,
            if: ->(event) {
                  ::Feature.enabled?(:handle_vulnerability_external_issue_link_via_events, event.project)
                }
        end

        def subscribe_to_work_item_events(store)
          store.subscribe ::WorkItems::RolledupDates::UpdateRolledupDatesEventHandler,
            to: ::WorkItems::WorkItemCreatedEvent
          store.subscribe ::WorkItems::RolledupDates::UpdateRolledupDatesEventHandler,
            to: ::WorkItems::WorkItemDeletedEvent
          store.subscribe ::WorkItems::RolledupDates::UpdateRolledupDatesEventHandler,
            to: ::WorkItems::WorkItemUpdatedEvent,
            if: ->(event) {
              ::WorkItems::RolledupDates::UpdateRolledupDatesEventHandler.can_handle_update?(event)
            }

          store.subscribe ::WorkItems::RolledupDates::BulkUpdateHandler,
            to: ::WorkItems::BulkUpdatedEvent,
            if: ->(event) {
              ::WorkItems::RolledupDates::BulkUpdateHandler.can_handle?(event)
            }

          store.subscribe ::WorkItems::ValidateEpicWorkItemSyncWorker,
            to: ::WorkItems::WorkItemCreatedEvent,
            if: ->(event) {
                  ::Namespace.find_by_id(event.data[:namespace_id])&.group_namespace? &&
                    ::Feature.enabled?(:validate_epic_work_item_sync,
                      ::Group.actor_from_id(event.data[:namespace_id])) &&
                    ::Epic.find_by_issue_id(event.data[:id]).present?
                }

          store.subscribe ::WorkItems::ValidateEpicWorkItemSyncWorker,
            to: ::WorkItems::WorkItemUpdatedEvent,
            if: ->(event) {
                  ::Namespace.find_by_id(event.data[:namespace_id])&.group_namespace? &&
                    ::Feature.enabled?(:validate_epic_work_item_sync,
                      ::Group.actor_from_id(event.data[:namespace_id])) &&
                    ::Epic.find_by_issue_id(event.data[:id]).present?
                }
        end

        def subscribe_to_milestone_events(store)
          store.subscribe ::WorkItems::RolledupDates::UpdateMilestoneRelatedWorkItemDatesEventHandler,
            to: ::Milestones::MilestoneUpdatedEvent,
            if: ->(event) {
              ::WorkItems::RolledupDates::UpdateMilestoneRelatedWorkItemDatesEventHandler.can_handle?(event)
            }
        end
      end
    end
  end
end
