# frozen_string_literal: true

module Search
  module Elastic
    module References
      class Embedding < Reference
        include Search::Elastic::Concerns::DatabaseReference
        include Search::Elastic::Concerns::RateLimiter
        extend Search::Elastic::Concerns::DatabaseClassReference

        MODEL_VERSIONS = { 0 => 'textembedding-gecko@003' }.freeze
        UNIT_PRIMITIVE = 'semantic_search_issue'

        override :serialize
        def self.serialize(record)
          ref(record).serialize
        end

        def self.ref(record)
          new(record.class, record.id, record.es_parent)
        end

        override :instantiate
        def self.instantiate(string)
          parts = delimit(string)
          new(*parts[1..])
        end

        attr_reader :model_klass, :identifier, :routing

        def initialize(model_klass, identifier, routing)
          @model_klass = model_klass.is_a?(String) ? model_klass.constantize : model_klass
          @identifier = identifier.to_i
          @routing = routing
        end

        override :serialize
        def serialize
          self.class.join_delimited([klass, model_klass, identifier, routing].compact)
        end

        override :as_indexed_json
        def as_indexed_json
          {
            embedding: embedding,
            embedding_version: 0,
            routing: routing
          }
        end

        override :operation
        def operation
          database_record ? :upsert : :delete
        end

        override :index_name
        def index_name
          model_klass.__elasticsearch__.index_name
        end

        private

        def embedding
          if embeddings_throttled_after_increment?
            raise ReferenceFailure, "Rate limited endpoint '#{ENDPOINT}' is throttled"
          end

          Gitlab::Llm::VertexAi::Embeddings::Text
            .new(content, user: nil, tracking_context: tracking_context, unit_primitive: UNIT_PRIMITIVE)
            .execute
        rescue StandardError => error
          raise ReferenceFailure, "Failed to generate embedding: #{error}"
        end

        def content
          "issue with title '#{database_record.title}' and description '#{database_record.description}'"
        end

        def tracking_context
          { action: "#{model_klass.name.underscore}_embedding" }
        end
      end
    end
  end
end
