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
            if: -> (_) { ::Gitlab::Geo.primary? }
          store.subscribe ::MergeRequests::StreamApprovalAuditEventWorker, to: ::MergeRequests::ApprovedEvent
          store.subscribe ::MergeRequests::ProcessApprovalAutoMergeWorker, to: ::MergeRequests::ApprovedEvent
          store.subscribe ::MergeRequests::CreateApprovalsResetNoteWorker, to: ::MergeRequests::ApprovalsResetEvent
          store.subscribe ::MergeRequests::ProcessApprovalAutoMergeWorker, to: ::MergeRequests::DraftStateChangeEvent
          store.subscribe ::MergeRequests::ProcessApprovalAutoMergeWorker, to: ::MergeRequests::UnblockedStateEvent
          store.subscribe ::MergeRequests::ProcessApprovalAutoMergeWorker,
            to: ::MergeRequests::ExternalStatusCheckPassedEvent
          store.subscribe ::PullMirrors::ReenableConfigurationWorker, to: ::GitlabSubscriptions::RenewedEvent
          store.subscribe ::Search::ElasticDefaultBranchChangedWorker,
            to: ::Repositories::DefaultBranchChangedEvent,
            if: -> (_) { ::Gitlab::CurrentSettings.elasticsearch_indexing? }
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

          register_threat_insights_subscribers(store)

          subscribe_to_epic_events(store)
          subscribe_to_external_issue_links_events(store)
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
                  ::Feature.enabled?(:validate_epic_work_item_sync, ::Group.actor_from_id(event.data[:group_id])) &&
                    ::Epic.has_work_item.id_in(event.data[:id]).exists?
                }
          store.subscribe ::WorkItems::ValidateEpicWorkItemSyncWorker,
            to: ::Epics::EpicUpdatedEvent,
            if: ->(event) {
                  ::Feature.enabled?(:validate_epic_work_item_sync, ::Group.actor_from_id(event.data[:group_id])) &&
                    ::Epic.has_work_item.id_in(event.data[:id]).exists?
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
      end
    end
  end
end
