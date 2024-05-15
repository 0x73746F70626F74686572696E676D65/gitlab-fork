# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clusters::AgentPolicy, feature_category: :remote_development do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:agent) { create(:ee_cluster_agent, project: project) }
  let_it_be(:anonymous) { nil }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user, owner_of: [project]) }
  let_it_be(:maintainer) { create(:user, maintainer_of: [project]) }
  let_it_be(:developer) { create(:user, developer_of: [project]) }
  let_it_be(:reporter) { create(:user, reporter_of: [project]) }
  let_it_be(:guest) { create(:user, guest_of: [project]) }

  subject(:policy) { described_class.new(user, agent) }

  describe "Static Roles" do
    where(:ability, :role, :admin_mode, :allowed) do
      :admin_remote_development_cluster_agent_mapping | :anonymous  | nil   | false
      :admin_remote_development_cluster_agent_mapping | :guest      | nil   | false
      :admin_remote_development_cluster_agent_mapping | :reporter   | nil   | false
      :admin_remote_development_cluster_agent_mapping | :developer  | nil   | false
      :admin_remote_development_cluster_agent_mapping | :maintainer | nil   | false
      :admin_remote_development_cluster_agent_mapping | :owner      | nil   | true
      :admin_remote_development_cluster_agent_mapping | :admin      | false | false
      :admin_remote_development_cluster_agent_mapping | :admin      | true  | true
    end

    with_them do
      let(:user) { public_send(role) }

      before do
        enable_admin_mode!(user) if admin_mode
      end

      if params[:allowed]
        it { is_expected.to be_allowed(ability) }
      else
        it { is_expected.not_to be_allowed(ability) }
      end
    end
  end
end
