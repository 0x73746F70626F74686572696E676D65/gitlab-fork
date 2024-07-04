# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::Projects::CreatorService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:source) { create(:project) }
  let(:existing_role) { :guest }
  let!(:existing_member) { create(:project_member, existing_role, user: user, project: source) }

  describe '.add_member' do
    context 'when inviting or promoting a member to a billable role' do
      it_behaves_like 'billable promotion management feature'
    end
  end

  describe '.add_members' do
    context 'when inviting or promoting a member to a billable role' do
      it_behaves_like 'billable promotion management for multiple users'
    end
  end
end
