# frozen_string_literal: true

module Search
  module Elastic
    module Concerns
      module DatabaseReference
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override
        include Gitlab::Utils::StrongMemoize

        override :operation
        def operation
          database_record ? :index : :delete
        end

        override :database_record
        def database_record
          model_klass.find_by_id(identifier)
        end
        strong_memoize_attr :database_record

        def database_record=(record)
          strong_memoize(:database_record) { record }
        end

        override :database_id
        def database_id
          database_record&.id
        end
      end
    end
  end
end
