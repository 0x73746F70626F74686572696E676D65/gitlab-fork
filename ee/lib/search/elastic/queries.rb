# frozen_string_literal: true

module Search
  module Elastic
    module Queries
      ADVANCED_QUERY_SYNTAX_REGEX = /[+*"\-|()~\\]/
      UNIT_PRIMITIVE = 'semantic_search_issue'
      KNN_K = 25
      KNN_NUM_CANDIDATES = 100

      class << self
        include ::Elastic::Latest::QueryContext::Aware
        include Search::Elastic::Concerns::RateLimiter

        def by_iid(iid:, doc_type:)
          bool_expr = Gitlab::Elastic::BoolExpr.new
          bool_expr.filter = [
            { term: { iid: { _name: context.name(doc_type, :related, :iid), value: iid } } },
            { term: { type: { _name: context.name(:doc, :is_a, doc_type), value: doc_type } } }
          ]

          {
            query: {
              bool: bool_expr
            }
          }
        end

        def by_multi_match_query(fields:, query:, options:)
          fields = ::Elastic::Latest::CustomLanguageAnalyzers.add_custom_analyzers_fields(fields)
          fields = remove_fields_boost(fields) if options[:count_only]

          bool_expr = Gitlab::Elastic::BoolExpr.new

          if query.present?
            bool_expr = Gitlab::Elastic::BoolExpr.new
            unless options[:no_join_project]
              bool_expr.filter << {
                term: {
                  type: {
                    _name: context.name(:doc, :is_a, options[:doc_type]),
                    value: options[:doc_type]
                  }
                }
              }
            end

            multi_match_bool = Gitlab::Elastic::BoolExpr.new
            multi_match_bool.should << multi_match_query(fields, query, options.merge(operator: :or))
            multi_match_bool.should << multi_match_query(fields, query, options.merge(operator: :and))
            multi_match_bool.should << multi_match_phrase_query(fields, query, options)
            multi_match_bool.minimum_should_match = 1

            if options[:count_only]
              bool_expr.filter << { bool: multi_match_bool }
            else
              bool_expr.must << { bool: multi_match_bool }
            end
          else
            bool_expr.must = { match_all: {} }
          end

          query_hash = { query: { bool: bool_expr } }
          query_hash[:track_scores] = true unless query.present?

          query_hash[:highlight] = apply_highlight(fields) unless options[:count_only]

          query_hash
        end

        def by_simple_query_string(fields:, query:, options:)
          fields = ::Elastic::Latest::CustomLanguageAnalyzers.add_custom_analyzers_fields(fields)
          fields = remove_fields_boost(fields) if options[:count_only]

          bool_expr = Gitlab::Elastic::BoolExpr.new
          if query.present?
            unless options[:no_join_project]
              bool_expr.filter << {
                term: {
                  type: {
                    _name: context.name(:doc, :is_a, options[:doc_type]),
                    value: options[:doc_type]
                  }
                }
              }
            end

            if options[:count_only]
              bool_expr.filter << simple_query_string(fields, query, options)
            else
              bool_expr.must << simple_query_string(fields, query, options)
            end
          else
            bool_expr.must = { match_all: {} }
          end

          query_hash = { query: { bool: bool_expr } }
          query_hash[:track_scores] = true unless query.present?

          query_hash[:highlight] = apply_highlight(fields) unless options[:count_only]

          query_hash
        end

        def by_knn(query_hash:, query:, options:)
          embedding = embedding(query, options)

          return query_hash unless embedding

          filters = query_hash.dig(:query, :bool, :filter)

          knn_query = {
            knn: {
              field: 'embedding',
              query_vector: embedding,
              k: KNN_K,
              num_candidates: KNN_NUM_CANDIDATES,
              similarity: options[:hybrid_similarity],
              filter: filters
            }
          }

          query_hash.merge(knn_query)
        rescue StandardError => e
          Gitlab::ErrorTracking.track_exception(e)
          query_hash
        end

        private

        def remove_fields_boost(fields)
          fields.map { |m| m.split('^').first }
        end

        def simple_query_string(fields, query, options)
          {
            simple_query_string: {
              _name: context.name(options[:doc_type], :match, :search_terms),
              fields: fields,
              query: query,
              lenient: true,
              default_operator: :and
            }
          }
        end

        def multi_match_phrase_query(fields, query, options)
          {
            multi_match: {
              _name: context.name(options[:doc_type], :multi_match_phrase, :search_terms),
              type: :phrase,
              fields: fields,
              query: query,
              lenient: true
            }
          }
        end

        def multi_match_query(fields, query, options)
          {
            multi_match: {
              _name: context.name(options[:doc_type], :multi_match, options[:operator], :search_terms),
              fields: fields,
              query: query,
              operator: options[:operator],
              lenient: true
            }
          }
        end

        def apply_highlight(fields)
          es_fields = fields.map { |field| field.split('^').first }.each_with_object({}) do |field, memo|
            memo[field.to_sym] = {}
          end

          # Adding number_of_fragments: 0 to not split results into snippets.
          # This way controllers can decide how to handle the highlighted data.
          {
            fields: es_fields,
            number_of_fragments: 0,
            pre_tags: [::Elastic::Latest::GitClassProxy::HIGHLIGHT_START_TAG],
            post_tags: [::Elastic::Latest::GitClassProxy::HIGHLIGHT_END_TAG]
          }
        end

        def embedding(query, options)
          tracking_context = { action: 'hybrid_issue_search_embedding' }
          user = options[:current_user]

          if embeddings_throttled_after_increment?
            raise StandardError, "Rate limited endpoint '#{ENDPOINT}' is throttled"
          end

          Gitlab::Llm::VertexAi::Embeddings::Text
            .new(query, user: user, tracking_context: tracking_context, unit_primitive: UNIT_PRIMITIVE)
            .execute
        end
      end
    end
  end
end
