# frozen_string_literal: true

class BackfillInitialEmbeddings < Elastic::Migration
  include Elastic::MigrationBackfillHelper

  skip_if -> do
    !(Gitlab::Saas.feature_available?(:ai_vertex_embeddings) &&
      Gitlab::Elastic::Helper.default.vectors_supported?(:elasticsearch))
  end

  # expected run time: 5 hours
  batched!
  batch_size 200
  throttle_delay 1.minute

  DOCUMENT_TYPE = Issue
  RECENCY = 1.year.ago
  PROJECT_IDS = [278964].freeze

  def field_names
    %w[embedding embedding_version]
  end

  def missing_field_filter
    {
      bool: {
        minimum_should_match: 1,
        should: fields_exist_query,
        filter: [
          project_filter,
          date_filter
        ],
        must: {
          term: {
            type: {
              value: DOCUMENT_TYPE.es_type
            }
          }
        }
      }
    }
  end

  def process_batch!
    query = {
      size: query_batch_size,
      query: {
        bool: {
          filter: missing_field_filter
        }
      }
    }

    results = client.search(index: index_name, body: query)
    hits = results.dig('hits', 'hits') || []

    embedding_references = hits.map! do |hit|
      id = hit.dig('_source', 'id')
      routing = hit['_routing']

      Search::Elastic::References::Embedding.new(DOCUMENT_TYPE, id, routing)
    end

    embedding_references.each_slice(update_batch_size) do |refs|
      Search::Elastic::ProcessEmbeddingBookkeepingService.track!(*refs)
    end

    embedding_references
  end

  def project_filter
    { bool: { should: project_shoulds, minimum_should_match: 1 } }
  end

  def project_shoulds
    projects.map do |project|
      { term: { project_id: project.id } }
    end
  end

  def date_filter
    { range: { updated_at: { gte: RECENCY.strftime('%Y-%m') } } }
  end

  def projects
    Project.id_in(PROJECT_IDS).select { |p| Feature.enabled?(:elasticsearch_issue_embedding, p, type: :ops) }
  end
end
