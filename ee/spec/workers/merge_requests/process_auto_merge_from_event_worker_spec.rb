# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ProcessAutoMergeFromEventWorker, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, merge_user: user) }
  let(:merge_request_id) { merge_request.id }

  let(:data) { { current_user_id: user.id, merge_request_id: merge_request_id } }

  it_behaves_like 'process auto merge from event worker' do
    let(:event) { MergeRequests::ApprovedEvent.new(data: data) }
  end

  it_behaves_like 'process auto merge from event worker' do
    let(:event) { ::MergeRequests::UnblockedStateEvent.new(data: data) }
  end

  it_behaves_like 'process auto merge from event worker' do
    let(:event) { ::MergeRequests::ExternalStatusCheckPassedEvent.new(data: data) }
  end

  it_behaves_like 'process auto merge from event worker' do
    let(:event) { ::MergeRequests::OverrideRequestedChangesStateEvent.new(data: data) }
  end

  it_behaves_like 'process auto merge from event worker' do
    let(:event) { MergeRequests::JiraTitleDescriptionUpdateEvent.new(data: data) }
  end
end
