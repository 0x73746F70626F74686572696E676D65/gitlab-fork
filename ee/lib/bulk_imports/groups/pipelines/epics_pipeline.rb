# frozen_string_literal: true

module BulkImports
  module Groups
    module Pipelines
      class EpicsPipeline
        include NdjsonPipeline
        include ::BulkImports::EpicObjectCreator

        relation_name 'epics'

        extractor ::BulkImports::Common::Extractors::NdjsonExtractor, relation: relation

        def load(_context, epic)
          return unless epic
          return if epic.persisted?

          create_epic(epic)
        end
      end
    end
  end
end
