# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::ProductAnalytics::GenerateCubeQueryService,
  :saas,
  feature_category: :product_analytics_visualization do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, group: group) }

  let(:current_user) { user }
  let(:resource) { project }
  let(:options) { {} }

  before_all do
    stub_feature_flags(ai_global_switch: true)
  end

  context 'when the user is permitted to generate a query for the project' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      allow(Ability).to receive(:allowed?).and_return(true)
      allow(current_user).to receive(:any_group_with_ai_available?).and_return(true)
      allow(Ability).to receive(:allowed?)
                          .with(user, :generate_cube_query, project)
                          .and_return(true)
    end

    let(:action_name) { :generate_cube_query }
    let(:content) { 'How many people used the application this week?' }

    it_behaves_like 'schedules completion worker' do
      subject { described_class.new(current_user, resource, options) }
    end
  end

  context 'when the user is not permitted to generate a query for the project' do
    before_all do
      project.add_guest(user)
    end

    before do
      allow(Ability).to receive(:allowed?).and_return(true)
      allow(current_user).to receive(:any_group_with_ai_available?).and_return(true)
      allow(Ability).to receive(:allowed?)
                          .with(user, :generate_cube_query, project)
                          .and_return(false)
    end

    it_behaves_like 'does not schedule completion worker' do
      subject { described_class.new(current_user, resource, options) }
    end
  end
end
