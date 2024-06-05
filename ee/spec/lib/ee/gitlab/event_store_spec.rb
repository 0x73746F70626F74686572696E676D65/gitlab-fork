# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::EventStore, feature_category: :shared do
  describe '.instance' do
    it 'returns a store with CE and EE subscriptions' do
      instance = described_class.instance

      expect(instance.subscriptions.keys).to match_array([
        ::Ci::JobArtifactsDeletedEvent,
        ::Ci::PipelineCreatedEvent,
        ::Repositories::KeepAroundRefsCreatedEvent,
        ::MergeRequests::ApprovedEvent,
        ::MergeRequests::ApprovalsResetEvent,
        ::MergeRequests::DraftStateChangeEvent,
        ::MergeRequests::UnblockedStateEvent,
        ::MergeRequests::OverrideRequestedChangesStateEvent,
        ::MergeRequests::DiscussionsResolvedEvent,
        ::GitlabSubscriptions::RenewedEvent,
        ::Repositories::DefaultBranchChangedEvent,
        ::NamespaceSettings::AiRelatedSettingsChangedEvent,
        ::Members::MembersAddedEvent,
        ::ProjectAuthorizations::AuthorizationsChangedEvent,
        ::ProjectAuthorizations::AuthorizationsRemovedEvent,
        ::ProjectAuthorizations::AuthorizationsAddedEvent,
        ::Projects::ComplianceFrameworkChangedEvent,
        ::ContainerRegistry::ImagePushedEvent,
        Projects::ProjectTransferedEvent,
        Groups::GroupTransferedEvent,
        Projects::ProjectArchivedEvent,
        Epics::EpicCreatedEvent,
        Epics::EpicUpdatedEvent,
        Vulnerabilities::LinkToExternalIssueTrackerCreated,
        Vulnerabilities::LinkToExternalIssueTrackerRemoved,
        WorkItems::WorkItemCreatedEvent,
        WorkItems::WorkItemDeletedEvent,
        WorkItems::WorkItemUpdatedEvent,
        PackageMetadata::IngestedAdvisoryEvent,
        MergeRequests::ExternalStatusCheckPassedEvent,
        Packages::PackageCreatedEvent,
        Projects::ProjectCreatedEvent,
        Projects::ProjectDeletedEvent,
        ::Milestones::MilestoneUpdatedEvent,
        ::WorkItems::BulkUpdatedEvent
      ])
    end
  end

  describe '.publish_group' do
    let(:events) { [] }

    it 'calls publish_group of instance' do
      expect(described_class.instance).to receive(:publish_group).with(events)

      described_class.publish_group(events)
    end
  end
end
