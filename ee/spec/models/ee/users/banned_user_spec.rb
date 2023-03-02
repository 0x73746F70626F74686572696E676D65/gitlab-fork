# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Users::BannedUser, feature_category: :global_search do
  include ElasticsearchHelpers

  let_it_be(:user) { create :user }
  let(:banned_user) { create :banned_user, user: user }

  describe '#after_commit' do
    context 'when add_hidden_to_issues migration is not finished' do
      it 'does not call reindex_issues when add_hidden_to_issues migration is not finished' do
        set_elasticsearch_migration_to :add_hidden_to_issues, including: false
        expect(ElasticAssociationIndexerWorker).not_to receive(:perform_async)
        banned_user
      end
    end

    context 'when add_hidden_to_issues migration is finished' do
      before do
        set_elasticsearch_migration_to :add_hidden_to_issues, including: true
      end

      it 'does not call reindex_issues on update' do
        banned_user
        expect(ElasticAssociationIndexerWorker).not_to receive(:perform_async)
        banned_user.touch
      end

      it 'calls reindex_issues on create' do
        expect(ElasticAssociationIndexerWorker).to receive(:perform_async).with(user.class.name, user.id, [:issues])
        banned_user
      end

      it 'calls reindex_issues on destroy' do
        banned_user
        expect(ElasticAssociationIndexerWorker).to receive(:perform_async).with(user.class.name, user.id, [:issues])
        banned_user.destroy!
      end
    end
  end
end
