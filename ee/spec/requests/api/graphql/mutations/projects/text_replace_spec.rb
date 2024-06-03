# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "projectTextReplace", feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { create(:user, owner_of: project) }
  let_it_be(:repo) { project.repository }

  let(:project_path) { project.full_path }
  let(:mutation_params) { { project_path: project_path, replacements: replacements } }
  let(:mutation) { graphql_mutation(:project_text_replace, mutation_params) }
  let(:replacements) { %w[p455w0rd] }
  let(:literal_replacements) { %w[literal:p455w0rd] }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  describe 'Replacing text' do
    before do
      ::Gitlab::GitalyClient.clear_stubs!

      allow_next_instance_of(Gitaly::CleanupService::Stub) do |instance|
        redactions = array_including(gitaly_request_with_params(redactions: literal_replacements))
        allow(instance).to receive(:rewrite_history)
          .with(redactions, kind_of(Hash))
          .and_return(Gitaly::RewriteHistoryResponse.new)
      end
    end

    context 'when audit events are licensed' do
      before do
        stub_licensed_features(audit_events: true)
      end

      it 'audits the changes' do
        expect { post_mutation }.to change { AuditEvent.count }.from(0).to(1)
        expect(AuditEvent.first.attributes.deep_symbolize_keys).to match a_hash_including(
          author_id: current_user.id,
          entity_id: project.id,
          target_id: project.id,
          details: a_hash_including(custom_message: 'Project text replaced')
        )
      end
    end

    context 'when audit events are not licensed' do
      before do
        stub_licensed_features(audit_events: false)
      end

      it 'does not audit the change' do
        expect { post_mutation }.not_to change { AuditEvent.count }
      end
    end
  end
end
