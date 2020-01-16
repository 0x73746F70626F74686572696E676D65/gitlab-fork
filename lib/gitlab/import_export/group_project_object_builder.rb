# frozen_string_literal: true

module Gitlab
  module ImportExport
    # Given a class, it finds or creates a new object
    # (initializes in the case of Label) at group or project level.
    # If it does not exist in the group, it creates it at project level.
    #
    # Example:
    #   `GroupProjectObjectBuilder.build(Label, label_attributes)`
    #    finds or initializes a label with the given attributes.
    #
    # It also adds some logic around Group Labels/Milestones for edge cases.
    class GroupProjectObjectBuilder
      # Cache keeps 1000 entries at most, 1000 is chosen based on:
      #    - one cache entry uses around 0.5K memory, 1000 items uses around 500K.
      #      (leave some buffer it should be less than 1M). It is afforable cost for project import.
      #    - for projects in Gitlab.com, it seems 1000 entries for labels/milestones is enough.
      #      For example, gitlab has ~970 labels and 26 milestones.
      LRU_CACHE_SIZE = 1000

      def self.build(*args)
        Project.transaction do
          new(*args).find
        end
      end

      def initialize(klass, attributes)
        @klass = klass < Label ? Label : klass
        @attributes = attributes
        @group = @attributes['group']
        @project = @attributes['project']

        if Gitlab::SafeRequestStore.active?
          @lru_cache = cache_from_request_store
          @cache_key = [klass, attributes]
        end
      end

      def find
        return if epic? && group.nil?

        find_with_cache do
          find_object || klass.create(project_attributes)
        end
      end

      private

      attr_reader :klass, :attributes, :group, :project, :lru_cache, :cache_key

      def find_with_cache
        return yield unless lru_cache && cache_key

        lru_cache[cache_key] ||= yield
      end

      def cache_from_request_store
        Gitlab::SafeRequestStore[:lru_cache] ||= LruRedux::Cache.new(LRU_CACHE_SIZE)
      end

      def find_object
        klass.where(where_clause).first
      end

      def where_clause
        where_clauses.reduce(:and)
      end

      def where_clauses
        [
          where_clause_base,
          where_clause_for_title,
          where_clause_for_klass
        ].compact
      end

      # Returns Arel clause `"{table_name}"."project_id" = {project.id}` if project is present
      # For example: merge_request has :target_project_id, and we are searching by :iid
      # or, if group is present:
      # `"{table_name}"."project_id" = {project.id} OR "{table_name}"."group_id" = {group.id}`
      def where_clause_base
        [].tap do |clauses|
          clauses << table[:project_id].eq(project.id) if project
          clauses << table[:group_id].eq(group.id) if group
        end.reduce(:or)
      end

      # Returns Arel clause `"{table_name}"."title" = '{attributes['title']}'`
      # if attributes has 'title key, otherwise `nil`.
      def where_clause_for_title
        attrs_to_arel(attributes.slice('title'))
      end

      # Returns Arel clause:
      # `"{table_name}"."{attrs.keys[0]}" = '{attrs.values[0]} AND {table_name}"."{attrs.keys[1]}" = '{attrs.values[1]}"`
      # from the given Hash of attributes.
      def attrs_to_arel(attrs)
        attrs.map do |key, value|
          table[key].eq(value)
        end.reduce(:and)
      end

      def table
        @table ||= klass.arel_table
      end

      def project_attributes
        attributes.except('group').tap do |atts|
          if label?
            atts['type'] = 'ProjectLabel' # Always create project labels
          elsif milestone?
            if atts['group_id'] # Transform new group milestones into project ones
              atts['iid'] = nil
              atts.delete('group_id')
            else
              claim_iid
            end
          end

          atts['importing'] = true if klass.ancestors.include?(Importable)
        end
      end

      def label?
        klass == Label
      end

      def milestone?
        klass == Milestone
      end

      def merge_request?
        klass == MergeRequest
      end

      def epic?
        klass == Epic
      end

      # If an existing group milestone used the IID
      # claim the IID back and set the group milestone to use one available
      # This is necessary to fix situations like the following:
      #  - Importing into a user namespace project with exported group milestones
      #    where the IID of the Group milestone could conflict with a project one.
      def claim_iid
        # The milestone has to be a group milestone, as it's the only case where
        # we set the IID as the maximum. The rest of them are fixed.
        milestone = project.milestones.find_by(iid: attributes['iid'])

        return unless milestone

        milestone.iid = nil
        milestone.ensure_project_iid!
        milestone.save!
      end

      protected

      # Returns Arel clause for a particular model or `nil`.
      def where_clause_for_klass
        return attrs_to_arel(attributes.slice('iid')) if merge_request?
      end
    end
  end
end

Gitlab::ImportExport::GroupProjectObjectBuilder.prepend_if_ee('EE::Gitlab::ImportExport::GroupProjectObjectBuilder')
