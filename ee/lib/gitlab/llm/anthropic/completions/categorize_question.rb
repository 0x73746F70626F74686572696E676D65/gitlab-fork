# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      module Completions
        class CategorizeQuestion < Gitlab::Llm::Completions::Base
          SCHEMA_URL = 'iglu:com.gitlab/ai_question_category/jsonschema/1-2-0'
          OUTPUT_TOKEN_LIMIT = 200

          private_class_method def self.load_xml(filename)
            File.read(File.join(File.dirname(__FILE__), '..', '..', 'fixtures', filename)).tr("\n", '')
          end

          LLM_MATCHING_CATEGORIES_XML = load_xml('categories.xml') # mandatory category definition
          LLM_MATCHING_LABELS_XML = load_xml('labels.xml') # boolean attribute definitions

          REQUIRED_KEYS = %w[detailed_category category].freeze
          OPTIONAL_KEYS = (
            %w[language] +
              Hash.from_xml(LLM_MATCHING_LABELS_XML)
                  .dig('root', 'label').pluck('type') # rubocop:disable CodeReuse/ActiveRecord -- Array#pluck
          ).freeze
          PERMITTED_KEYS = REQUIRED_KEYS + OPTIONAL_KEYS

          def execute
            @ai_client = ::Gitlab::Llm::Anthropic::Client.new(user,
              unit_primitive: 'categorize_duo_chat_question', tracking_context: tracking_context)
            @storage = ::Gitlab::Llm::ChatStorage.new(user)
            @messages = @storage.messages_up_to(options[:message_id])
            @logger = Gitlab::Llm::Logger.build

            if track(user, attributes)
              ResponseModifiers::CategorizeQuestion.new(nil)
            else
              ResponseModifiers::CategorizeQuestion.new(error: 'Event not tracked')
            end
          end

          private

          attr_reader :messages

          def request(template)
            @ai_client.complete(
              max_tokens_to_sample: OUTPUT_TOKEN_LIMIT,
              prompt: template.to_prompt
            )&.dig("completion").to_s.strip
          end

          def attributes
            attributes_from_llm.merge(
              Gitlab::Llm::ChatMessageAnalyzer.new(messages).execute
            )
          end

          def attributes_from_llm
            template = ai_prompt_class.new(messages, options)
            data = Gitlab::Json.parse(request(template)) || {}

            # Turn array of matched label strings into boolean attributes
            labels = data.delete('labels')
            labels&.each { |label| data[label] = true }

            data.slice(*PERMITTED_KEYS)
          rescue JSON::ParserError
            error_message = "JSON has an invalid format."
            @logger.error(message: "Error", class: self.class.to_s, error: error_message)
            {}
          end

          def track(user, attributes)
            return false if attributes.empty?

            unless contains_categories?(attributes)
              error_message = 'Response did not contain defined categories'
              @logger.error(message: "Error", class: self.class.to_s, error: error_message)
              return false
            end

            context = SnowplowTracker::SelfDescribingJson.new(SCHEMA_URL, attributes)

            Gitlab::Tracking.event(
              self.class.to_s,
              "ai_question_category",
              context: [context],
              property: tracking_context[:request_id],
              user: user
            )
          end

          def contains_categories?(hash)
            REQUIRED_KEYS.each do |key|
              return false unless hash.has_key?(key)
            end
          end
        end
      end
    end
  end
end
