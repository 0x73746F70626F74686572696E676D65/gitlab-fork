# frozen_string_literal: true

module Gitlab
  module Llm
    class TanukiBot
      include ::Gitlab::Loggable
      include Langsmith::RunHelpers

      REQUEST_TIMEOUT = 30
      CONTENT_ID_FIELD = 'ATTRS'
      CONTENT_ID_REGEX = /CNT-IDX-(?<id>\d+)/
      RECORD_LIMIT = 4

      def self.enabled_for?(user:, container: nil)
        return false unless Feature.enabled?(:ai_duo_chat_switch, type: :ops)

        return false unless user

        authorizer_response = if container
                                Gitlab::Llm::Chain::Utils::ChatAuthorizer.container(container: container, user: user)
                              else
                                Gitlab::Llm::Chain::Utils::ChatAuthorizer.user(user: user)
                              end

        authorizer_response.allowed?
      end

      def self.show_breadcrumbs_entry_point?(user:, container: nil)
        return false unless Feature.enabled?(:tanuki_bot_breadcrumbs_entry_point, user)

        enabled_for?(user: user, container: container)
      end

      def initialize(current_user:, question:, logger: nil, tracking_context: {})
        @current_user = current_user
        @question = question
        @logger = logger || Gitlab::Llm::Logger.build
        @correlation_id = Labkit::Correlation::CorrelationId.current_id
        @tracking_context = tracking_context
      end

      def execute(&block)
        return empty_response unless question.present?
        return empty_response unless self.class.enabled_for?(user: current_user)

        unless ::Embedding::Vertex::GitlabDocumentation.table_exists?
          logger.info_or_debug(current_user, message: "Embeddings database does not exist")

          return unsupported_response
        end

        unless ::Embedding::Vertex::GitlabDocumentation.any?
          logger.info_or_debug(current_user, message: "Need to query docs but no embeddings are found")

          return empty_response
        end

        embedding = embedding_for_question(question)
        return empty_response if embedding.nil?

        search_documents = get_nearest_neighbors(embedding)
        return empty_response if search_documents.empty?

        get_completions(search_documents, &block)
      end

      # Note: a Rake task is using this method to extract embeddings for a test fixture.
      def embedding_for_question(question)
        result = vertex_client.text_embeddings(content: question)

        if !result.success? || !result.has_key?('predictions')
          logger.info_or_debug(current_user, message: "Could not generate embeddings",
            error: result.dig('error', 'message'))
          nil
        else
          result['predictions'].first&.dig('embeddings', 'values')
        end
      end

      # Note: a Rake task is using this method to extract embeddings for a test fixture.
      def get_nearest_neighbors(embedding)
        ::Embedding::Vertex::GitlabDocumentation.current.neighbor_for(
          embedding,
          limit: RECORD_LIMIT
        ).map do |item|
          item.metadata['source_url'] = item.url

          content = Gitlab::Llm::Embeddings::Utils::DocsAbsoluteUrlConverter.convert(item.content, item.url)

          {
            id: item.id,
            content: content,
            metadata: item.metadata
          }
        end
      end
      traceable :get_nearest_neighbors, name: 'Retrieve GitLab documents', run_type: 'retriever'

      private

      attr_reader :current_user, :question, :logger, :correlation_id, :tracking_context

      def vertex_client
        @vertex_client ||= ::Gitlab::Llm::VertexAi::Client.new(current_user, tracking_context: tracking_context)
      end

      def anthropic_client
        @anthropic_client ||= ::Gitlab::Llm::Anthropic::Client.new(current_user, tracking_context: tracking_context)
      end

      def get_completions(search_documents)
        final_prompt = Gitlab::Llm::Anthropic::Templates::TanukiBot
          .final_prompt(question: question, documents: search_documents)

        final_prompt_result = anthropic_client.stream(
          prompt: final_prompt[:prompt]
        ) do |data|
          logger.info(message: "Streaming error", error: data&.dig("error")) if data&.dig("error")

          yield data&.dig("completion").to_s if block_given?
        end

        logger.info_or_debug(current_user,
          message: "Got Final Result", prompt: final_prompt[:prompt], response: final_prompt_result)

        Gitlab::Llm::Anthropic::ResponseModifiers::TanukiBot.new(
          { completion: final_prompt_result }.to_json, current_user
        )
      end

      def empty_response
        Gitlab::Llm::ResponseModifiers::EmptyResponseModifier.new(
          _("I'm sorry, I was not able to find any documentation to answer your question.")
        )
      end

      def unsupported_response
        Gitlab::Llm::ResponseModifiers::EmptyResponseModifier.new(
          _("It seems your question relates to GitLab documentation. " \
            "Unfortunately, this feature is not yet available in this GitLab instance. " \
            "Your feedback is welcome.")
        )
      end
    end
  end
end
