# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class Base
      DEFAULT_CODE_SUGGESTIONS_URL = 'https://codesuggestions.gitlab.com'
      AI_GATEWAY_CONTENT_SIZE = 100_000

      def initialize(params: {}, unsafe_passthrough_params: {})
        @params = params
        @unsafe_passthrough_params = unsafe_passthrough_params
      end

      def endpoint
        base_url = ENV.fetch('CODE_SUGGESTIONS_BASE_URL', DEFAULT_CODE_SUGGESTIONS_URL)

        "#{base_url}/v2/code/#{endpoint_name}"
      end

      def body
        body_params = unsafe_passthrough_params.merge(prompt.request_params)

        trim_content_params(body_params)

        body_params.to_json
      end

      private

      attr_reader :params, :unsafe_passthrough_params

      def endpoint_name
        raise NotImplementedError
      end

      def trim_content_params(body_params)
        return unless body_params[:current_file]

        body_params[:current_file][:content_above_cursor] =
          body_params[:current_file][:content_above_cursor].to_s.last(AI_GATEWAY_CONTENT_SIZE)
        body_params[:current_file][:content_below_cursor] =
          body_params[:current_file][:content_below_cursor].to_s.first(AI_GATEWAY_CONTENT_SIZE)
      end
    end
  end
end
