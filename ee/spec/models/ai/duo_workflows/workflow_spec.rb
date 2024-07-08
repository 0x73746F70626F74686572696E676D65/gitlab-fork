# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::Workflow, feature_category: :duo_workflow do
  let(:user) { create(:user) }
  let(:workflow) { create(:duo_workflows_workflow, user: user) }

  describe '.for_user_with_id!' do
    it 'finds the workflow for the given user and id' do
      expect(described_class.for_user_with_id!(user.id, workflow.id)).to eq(workflow)
    end

    it 'raises an error if the workflow is for a different user' do
      different_user = create(:user)

      expect { described_class.for_user_with_id!(different_user, workflow.id) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
  end

  describe 'state transitions' do
    using RSpec::Parameterized::TableSyntax
    where(:status, :can_start, :can_pause, :can_resume, :can_finish, :can_drop) do
      0 | true  | false | false | false | true
      1 | false | true  | false | true  | true
      2 | false | false | true  | false | true
      3 | false | false | false | false | false
      4 | false | false | false | false | false
    end

    with_them do
      it 'adheres to state machine rules', :aggregate_failures do
        workflow.status = status

        expect(workflow.can_start?).to eq(can_start)
        expect(workflow.can_pause?).to eq(can_pause)
        expect(workflow.can_resume?).to eq(can_resume)
        expect(workflow.can_finish?).to eq(can_finish)
        expect(workflow.can_drop?).to eq(can_drop)
      end
    end
  end
end
