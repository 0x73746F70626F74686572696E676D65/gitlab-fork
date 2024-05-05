# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      module Utils
        # Defines value parsing and formatting routines for backup metadata JSON
        module MetadataSerialization
          module_function

          # Given a JSON primitive +value+ loaded from a file, cast it to the
          # expected class as specified by +type+
          #
          # @param [Symbol] type
          # @param [Object] value
          # @return [Object] the parsed and converted value
          def parse_value(type:, value:)
            return value if value.nil?

            case type
            when :string then parse_string(value)
            when :time then parse_time(value)
            when :integer then parse_integer(value)
            else
              fail NameError, "Unknown data type key #{type.inspect} provided when parsing backup metadata"
            end
          end

          # Given a metadata value, prepare and format the value as a
          # JSON primitive type before serializing
          #
          # @param [Symbol] type
          # @param [Object] value
          # @return [Object] the converted JSON primitive value
          def serialize_value(type:, value:)
            return value if value.nil?

            case type
            when :string then serialize_string(value)
            when :time then serialize_time(value)
            when :integer then serialize_integer(value)
            else
              fail NameError, "Unknown data type key #{type.inspect} provided when serializing backup metadata"
            end
          end

          def parse_string(value)
            return value if value.nil?
            value.to_s
          end

          def parse_time(value)
            return value if value.is_a?(Time) || value.nil?
            Time.parse(value.to_s)
          end

          def parse_integer(value)
            return value if value.is_a?(Integer) || value.nil?

            value.to_s.to_i
          end

          def serialize_integer(value)
            return value if value.nil?
            value.to_i
          end

          def serialize_string(value)
            value.to_s
          end

          def serialize_time(value)
            # ensures string values and nil are properly cast to Time objects
            time = parse_time(value)
            time&.iso8601
          end
        end
      end
    end
  end
end
