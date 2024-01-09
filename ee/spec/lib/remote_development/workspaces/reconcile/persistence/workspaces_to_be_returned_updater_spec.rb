# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
RSpec.describe RemoteDevelopment::Workspaces::Reconcile::Persistence::WorkspacesToBeReturnedUpdater, feature_category: :remote_development do
  let_it_be(:user) { create(:user) }
  let_it_be(:agent) { create(:ee_cluster_agent, :with_remote_development_agent_config) }

  let_it_be(:workspace1) do
    create(
      :workspace,
      :without_realistic_after_create_timestamp_updates,
      name: "workspace1",
      agent: agent,
      user: user,
      force_include_all_resources: false
    )
  end

  let_it_be(:workspace2) do
    create(
      :workspace,
      :without_realistic_after_create_timestamp_updates,
      name: "workspace2",
      agent: agent,
      user: user,
      force_include_all_resources: false
    )
  end

  let_it_be(:workspace3) do
    create(
      :workspace,
      :without_realistic_after_create_timestamp_updates,
      name: "workspace3",
      agent: agent,
      user: user,
      force_include_all_resources: true
    )
  end

  let(:workspaces_to_be_returned) { [workspace1, workspace2, workspace3] }

  let(:value) do
    {
      agent: agent,
      workspaces_to_be_returned: workspaces_to_be_returned
    }
  end

  subject(:returned_value) do
    described_class.update(value) # rubocop:disable Rails/SaveBang -- This is not an ActiveRecord method
  end

  before do
    workspace1.update_attribute(:responded_to_agent_at, 2.hours.ago)
    workspace2.update_attribute(:responded_to_agent_at, 2.hours.ago)
    workspace3.update_attribute(:responded_to_agent_at, 2.hours.ago)
    agent.reload
  end

  context "with fixture sanity checks" do
    it "has the expected fixtures" do
      expect(workspace1.responded_to_agent_at).to be < 1.hour.ago
      expect(workspace2.responded_to_agent_at).to be < 1.hour.ago
    end
  end

  context "for update_type FULL" do
    it "updates all workspaces", :unlimited_max_formatted_output_length do
      returned_value
      expect(workspace1.reload.responded_to_agent_at).to be > 1.minute.ago
      expect(workspace2.reload.responded_to_agent_at).to be > 1.minute.ago
      expect(workspace3.reload.responded_to_agent_at).to be > 1.minute.ago
    end

    it "preserves existing value entries" do
      returned_value
      expect(returned_value).to eq(value.merge(workspaces_to_be_returned: [workspace1.reload, workspace2.reload,
        workspace3.reload]))
    end

    it 'resets force_include_all_resources to false for workspaces with true' do
      expect { returned_value }.to change { workspace3.reload.force_include_all_resources }.from(true).to(false)
    end

    it 'does not change force_include_all_resources for workspaces with false' do
      expect { returned_value }.not_to change { workspace1.reload.force_include_all_resources }
      expect { returned_value }.not_to change { workspace2.reload.force_include_all_resources }
    end
  end
end
