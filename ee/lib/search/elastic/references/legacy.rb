# frozen_string_literal: true

module Search
  module Elastic
    module References
      class Legacy < Reference
        def self.serialize(record)
          Gitlab::Elastic::DocumentReference.serialize_record(record)
        end

        override :instantiate
        def self.instantiate(string)
          Gitlab::Elastic::DocumentReference.deserialize(string)
        end
      end
    end
  end
end
