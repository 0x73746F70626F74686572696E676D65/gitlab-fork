# frozen_string_literal: true

module Search
  module Elastic
    module Queries
      class << self
        include ::Elastic::Latest::QueryContext::Aware

        AGGREGATION_LIMIT = 500

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

        def by_simple_query_string(fields:, query:, options:)
          fields = ::Elastic::Latest::CustomLanguageAnalyzers.add_custom_analyzers_fields(fields)

          fields = remove_fields_boost(fields) if options[:count_only]

          query_hash =
            if query.present?
              simple_query_string = simple_query_string(fields, query, options)

              build_bool_query(simple_query_string, options)
            else
              bool_expr = Gitlab::Elastic::BoolExpr.new
              bool_expr.must = { match_all: {} }
              {
                query: {
                  bool: bool_expr
                },
                track_scores: true
              }
            end

          if options[:count_only]
            query_hash[:size] = 0
          else
            query_hash[:highlight] = apply_highlight(fields)
          end

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

        def build_bool_query(simple_query_string, options)
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

          if options[:count_only]
            bool_expr.filter << simple_query_string
          else
            bool_expr.must << simple_query_string
          end

          {
            query: {
              bool: bool_expr
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
      end
    end
  end
end
