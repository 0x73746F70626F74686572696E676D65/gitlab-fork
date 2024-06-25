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

        search_documents = get_search_results(question)

        return empty_response if search_documents.blank?

        get_completions_ai_gateway(search_documents, &block)
      end

      def get_search_results(question)
        response = Gitlab::Llm::AiGateway::DocsClient.new(current_user)
          .search(query: question) || {}

        response.dig('response', 'results')&.map(&:with_indifferent_access)
      end

      private

      attr_reader :current_user, :question, :logger, :correlation_id, :tracking_context

      def vertex_client
        @vertex_client ||= ::Gitlab::Llm::VertexAi::Client.new(current_user,
          unit_primitive: 'documentation_search', tracking_context: tracking_context)
      end

      def anthropic_client
        @anthropic_client ||= ::Gitlab::Llm::Anthropic::Client.new(current_user,
          unit_primitive: 'documentation_search', tracking_context: tracking_context)
      end

      def ai_gateway_request
        @ai_gateway_request ||= ::Gitlab::Llm::Chain::Requests::AiGateway.new(current_user,
          tracking_context: tracking_context)
      end

      def get_completions_ai_gateway(search_documents)
        final_prompt = Gitlab::Llm::Anthropic::Templates::TanukiBot
          .final_prompt(question: question, documents: search_documents)

        final_prompt_result = ai_gateway_request.request(
          prompt: final_prompt[:prompt], options: final_prompt[:options]
        ) do |data|
          yield data if block_given?
        end

        logger.info_or_debug(current_user,
          message: "Got Final Result", prompt: final_prompt[:prompt], response: final_prompt_result)

        Gitlab::Llm::Anthropic::ResponseModifiers::TanukiBot.new(
          { completion: final_prompt_result }.to_json,
          current_user,
          search_documents: search_documents
        )

      rescue Gitlab::Llm::AiGateway::Client::ConnectionError => error
        Gitlab::ErrorTracking.track_exception(error)

        logger.info(message: "Streaming error", error: error.message)
      end

      def empty_response
        Gitlab::Llm::ResponseModifiers::EmptyResponseModifier.new(
          s_("AI|I'm sorry, I couldn't find any documentation to answer your question."),
          error_code: empty_response_code
        )
      end

      def empty_response_code
        "M2000"
      end
    end
  end
end
