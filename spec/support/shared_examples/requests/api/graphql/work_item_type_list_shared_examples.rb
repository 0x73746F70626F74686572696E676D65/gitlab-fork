# frozen_string_literal: true

RSpec.shared_examples 'graphql work item type list request spec' do
  include_context 'with work item types request context'

  context 'when user has access to the group' do
    it_behaves_like 'a working graphql query that returns data' do
      before do
        post_graphql(query, current_user: current_user)
      end
    end

    it 'returns all default work item types' do
      post_graphql(query, current_user: current_user)

      expect(graphql_data_at(parent_key, :workItemTypes, :nodes)).to match_array(expected_work_item_type_response)
    end

    it 'prevents N+1 queries' do
      # Destroy 2 existing types
      WorkItems::Type.by_type([:issue, :task]).delete_all

      post_graphql(query, current_user: current_user) # warm-up

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { post_graphql(query, current_user: current_user) }
      expect(graphql_errors).to be_blank

      # Add back the 2 deleted types
      expect do
        Gitlab::DatabaseImporters::WorkItems::BaseTypeImporter.upsert_types
      end.to change { WorkItems::Type.count }.by(2)

      expect { post_graphql(query, current_user: current_user) }.to issue_same_number_of_queries_as(control)
      expect(graphql_errors).to be_blank
    end
  end

  context "when user doesn't have access to the parent" do
    let(:current_user) { create(:user) }

    before do
      post_graphql(query, current_user: current_user)
    end

    it 'does not return the parent' do
      expect(graphql_data).to eq(parent_key.to_s => nil)
    end
  end
end
