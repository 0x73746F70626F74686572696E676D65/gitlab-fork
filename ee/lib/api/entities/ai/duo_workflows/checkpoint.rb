# frozen_string_literal: true

module API
  module Entities
    module Ai
      module DuoWorkflows
        class Checkpoint < Grape::Entity
          expose :id
          expose :thread_ts
          expose :parent_ts
          expose :checkpoint
          expose :metadata
        end
      end
    end
  end
end
