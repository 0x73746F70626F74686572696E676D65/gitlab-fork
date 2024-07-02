# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::Workflow, feature_category: :duo_workflow do
  describe '.for_user_with_id!' do
    let(:user) { create(:user) }
    let(:workflow) { create(:duo_workflows_workflow, user: user) }

    it 'finds the workflow for the given user and id' do
      expect(described_class.for_user_with_id!(user.id, workflow.id)).to eq(workflow)
    end

    it 'raises an error if the workflow is for a different user' do
      different_user = create(:user)

      expect { described_class.for_user_with_id!(different_user, workflow.id) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
