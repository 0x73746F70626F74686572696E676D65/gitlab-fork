# frozen_string_literal: true

module Search
  module Elastic
    module Types
      class WorkItem
        def self.index_name
          Search::Elastic::References::WorkItem.index
        end

        def self.target
          ::WorkItem
        end

        def self.mappings
          {
            dynamic: 'strict',
            properties: {
              type: { type: 'keyword' },
              id: { type: 'integer' },
              iid: { type: 'integer' },
              title: { type: 'text', index_options: 'positions', analyzer: :title_analyzer },
              description: { type: 'text', index_options: 'positions', analyzer: :code_analyzer },
              namespace_id: { type: 'integer' },
              root_namespace_id: { type: 'integer' },
              created_at: { type: 'date' },
              updated_at: { type: 'date' },
              due_date: { type: 'date' },
              state: { type: 'keyword' },
              project_id: { type: 'integer' },
              author_id: { type: 'integer' },
              confidential: { type: 'boolean' },
              hidden: { type: 'boolean' },
              archived: { type: 'boolean' },
              assignee_id: { type: 'integer' },
              project_visibility_level: { type: 'short' },
              namespace_visibility_level: { type: 'short' },
              work_item_access_level: { type: 'short' },
              upvotes: { type: 'integer' },
              traversal_ids: { type: 'keyword' },
              label_ids: { type: 'keyword' },
              hashed_root_namespace_id: { type: 'integer' },
              work_item_type_id: { type: 'integer' },
              schema_version: { type: 'short' }
            }
          }
        end

        def self.settings
          ::Elastic::Latest::Config.settings.to_hash.deep_merge(
            index: ::Elastic::Latest::Config.separate_index_specific_settings(index_name)
          )
        end
      end
    end
  end
end
