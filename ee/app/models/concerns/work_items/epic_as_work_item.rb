# frozen_string_literal: true

module WorkItems
  module EpicAsWorkItem
    extend ActiveSupport::Concern

    included do
      include Gitlab::Utils::StrongMemoize

      has_many :own_label_links, class_name: 'LabelLink', as: :target, inverse_of: :target
      has_many :own_labels, through: :own_label_links
      has_many :labels, through: :label_links do
        def load_target
          return super unless proxy_association.owner.unified_association?

          proxy_association.target = scope.to_a unless proxy_association.loaded?

          proxy_association.loaded!
          proxy_association.target
        end

        def find(*args)
          return super unless proxy_association.owner.unified_association?
          return super if block_given?

          scope.find(*args)
        end

        def replace(other_array)
          return super unless proxy_association.owner.unified_association?

          to_be_removed = proxy_association.target - other_array
          to_be_added = other_array - proxy_association.target

          LabelLink.where(label_id: scope.where(id: to_be_removed).select(:id)).delete_all unless to_be_removed.blank?

          proxy_association.target -= to_be_removed
          proxy_association.concat(to_be_added)

          self
        end

        # important to have this method overwritten as most collection proxy method methods are delegated to the scope
        def scope
          Label.from_union(
            [
              proxy_association.owner.sync_object&.own_labels || Label.none,
              proxy_association.owner.own_labels
            ],
            remove_duplicates: true
          )
        end
      end

      def labels=(array)
        super if !try(:sync_object) || !unification_enabled?

        labels.replace(array)
      end

      def container
        case resource_parent
        when Group
          resource_parent
        when Project
          resource_parent.group
        end
      end

      strong_memoize_attr :container

      def unified_association?
        unification_enabled? && try(:sync_object)
      end

      def unification_enabled?
        container&.epic_and_work_item_labels_unification_enabled?
      end
    end
  end
end
