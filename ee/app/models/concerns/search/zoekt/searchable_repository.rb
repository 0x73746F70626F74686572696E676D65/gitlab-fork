# frozen_string_literal: true

module Search
  module Zoekt
    module SearchableRepository
      extend ActiveSupport::Concern

      included do
        def use_zoekt?
          project&.use_zoekt?
        end

        def update_zoekt_index!(force: false)
          node_id = ::Search::Zoekt.fetch_node_id(project.root_ancestor)
          ::Gitlab::Search::Zoekt::Client.index(project, node_id, force: force)
        end

        def async_update_zoekt_index
          ::Search::Zoekt.index_async(project.id)
        end
      end
    end
  end
end
