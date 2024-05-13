# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ExternalStatusChecks::CreateService do
  let_it_be(:project) { create(:project) }
  let_it_be(:protected_branch) { create(:protected_branch, project: project) }
  let_it_be(:user) { create(:user) }

  let(:action_allowed) { true }

  let(:params) do
    {
      name: 'Test',
      external_url: 'https://external_url.text/hello.json',
      protected_branch_ids: [protected_branch.id]
    }
  end

  before do
    allow(Ability)
      .to receive(:allowed?).with(user, :manage_merge_request_settings, project)
                            .and_return(action_allowed)

    stub_licensed_features(audit_events: true)
  end

  subject(:execute) { described_class.new(container: project, current_user: user, params: params).execute }

  it_behaves_like 'create external status services'
end
