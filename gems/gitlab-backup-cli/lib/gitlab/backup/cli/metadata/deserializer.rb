# frozen_string_literal: true

module Gitlab
  module Backup
    module Cli
      module Metadata
        module Deserializer
          extend self

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
              raise NameError, "Unknown data type key #{type.inspect} provided when parsing backup metadata"
            end
          end

          # @param [Object] value
          def parse_string(value)
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
        end
      end
    end
  end
end
