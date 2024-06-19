# frozen_string_literal: true

module Ci
  class PipelineMessage < Ci::ApplicationRecord
    include Ci::Partitionable
    include SafelyChangeColumnDefault

    columns_changing_default :partition_id

    MAX_CONTENT_LENGTH = 10_000

    belongs_to :pipeline

    validates :content, presence: true

    partitionable scope: :pipeline

    before_save :truncate_long_content

    enum severity: { error: 0, warning: 1 }

    private

    def truncate_long_content
      return if content.length <= MAX_CONTENT_LENGTH

      self.content = content.truncate(MAX_CONTENT_LENGTH)
    end
  end
end
