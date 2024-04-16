# frozen_string_literal: true

module Ci
  module Catalog
    # This class represents a CI/CD Catalog resource.
    # A Catalog resource is normally associated to a project.
    # This model connects to the `main` database because of its
    # dependency on the Project model and its need to join with that table
    # in order to generate the CI/CD catalog.
    class Resource < ::ApplicationRecord
      include PgFullTextSearchable
      include Gitlab::VisibilityLevel
      include Sortable

      self.table_name = 'catalog_resources'

      belongs_to :project
      has_many :components, class_name: 'Ci::Catalog::Resources::Component', foreign_key: :catalog_resource_id,
        inverse_of: :catalog_resource
      has_many :component_usages, class_name: 'Ci::Catalog::Resources::Components::Usage',
        foreign_key: :catalog_resource_id, inverse_of: :catalog_resource
      has_many :versions, class_name: 'Ci::Catalog::Resources::Version', foreign_key: :catalog_resource_id,
        inverse_of: :catalog_resource
      has_many :sync_events, class_name: 'Ci::Catalog::Resources::SyncEvent', foreign_key: :catalog_resource_id,
        inverse_of: :catalog_resource

      enum verification_level: VerifiedNamespace::VERIFICATION_LEVELS

      scope :for_projects, ->(project_ids) { where(project_id: project_ids) }

      # The `search_vector` column contains a tsvector that has a greater weight on `name` than `description`.
      # The vector is automatically generated by the database when `name` or `description` is updated.
      scope :search, ->(query) { pg_full_text_search_in_model(query) }

      scope :order_by_created_at_desc, -> { reorder(created_at: :desc) }
      scope :order_by_created_at_asc, -> { reorder(created_at: :asc) }
      scope :order_by_name_desc, -> { reorder(arel_table[:name].desc.nulls_last) }
      scope :order_by_name_asc, -> { reorder(arel_table[:name].asc.nulls_last) }
      scope :order_by_latest_released_at_desc, -> { reorder(arel_table[:latest_released_at].desc.nulls_last) }
      scope :order_by_latest_released_at_asc, -> { reorder(arel_table[:latest_released_at].asc.nulls_last) }
      scope :order_by_star_count, ->(direction) do
        build_keyset_order_on_joined_column(
          scope: joins(:project),
          attribute_name: 'project_star_count',
          column: Project.arel_table[:star_count],
          direction: direction,
          nullable: :nulls_last
        )
      end

      delegate :avatar_path, :star_count, :full_path, to: :project

      enum state: { unpublished: 0, published: 1 }

      before_create :sync_with_project

      class << self
        def public_or_visible_to_user(user)
          return public_to_user unless user

          where(
            'EXISTS (?) OR catalog_resources.visibility_level IN (?)',
            user.authorizations_for_projects(related_project_column: 'catalog_resources.project_id'),
            Gitlab::VisibilityLevel.levels_for_user(user)
          )
        end

        def visible_to_user(user)
          return none unless user

          where_exists(user.authorizations_for_projects(related_project_column: 'catalog_resources.project_id'))
        end

        # Used by Ci::ProcessSyncEventsService
        def sync!(event)
          # There may be orphaned records since this table does not enforce FKs
          event.catalog_resource&.sync_with_project!
        end
      end

      def to_param
        full_path
      end

      def publish!
        update!(state: :published)
      end

      def sync_with_project!
        sync_with_project
        save!
      end

      # Triggered in Ci::Catalog::Resources::Version and Release model callbacks
      def update_latest_released_at!
        update!(latest_released_at: versions.latest&.released_at)
      end

      def visibility_level_field
        :visibility_level
      end

      private

      # These denormalized columns are first synced when a new catalog resource is created.
      # A PG trigger adds a SyncEvent when the associated project updates any of these columns.
      # A worker processes the SyncEvents with Ci::ProcessSyncEventsService.
      def sync_with_project
        self.name = project.name
        self.description = project.description
        self.visibility_level = project.visibility_level
      end
    end
  end
end

Ci::Catalog::Resource.prepend_mod_with('Ci::Catalog::Resource')
