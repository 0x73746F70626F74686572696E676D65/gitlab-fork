# frozen_string_literal: true

module UseSqlFunctionForPrimaryKeyLookups
  extend ActiveSupport::Concern

  class_methods do
    def _query_by_sql(sql, ...)
      return super unless Feature.enabled?(:use_sql_functions_for_primary_key_lookups, Feature.current_request)

      replaced = try_replace_with_function_call(sql)

      return super unless replaced

      super(replaced.arel, ...)
    end

    def cached_find_by_statement(key, &block)
      return super unless Feature.enabled?(:use_sql_functions_for_primary_key_lookups, Feature.current_request)

      transformed_block = proc do |params|
        original = yield(params)

        replaced = try_replace_with_function_call(original.arel)
        replaced || original
      end
      super(key, &transformed_block)
    end

    # Tries to replace an arel representation of a primary key lookup with an optimized function call.
    #
    # Returns nil if the optimization was not possible
    # Returns a relation (not arel!) if the optimization was successful
    # This needs to take arel and return a relation because in one code path to transform rails is passing arel,
    # and in another it's passing a relation.
    # After the patch we need to return the same type, so depending on the patch location we call .arel on the return
    # if we need arel back.
    def try_replace_with_function_call(arel)
      # The beginning of this method speculatively assumes that the arel passed in represents a query of the form
      # SELECT <all columns> FROM <table> WHERE id = <number> generated by a rails find-by-primary-key style query
      # As we rely on details of the arel tree, we return nil (meaning that we failed to replace with a function call)
      # if the structure is not what we expected
      return unless arel.is_a?(Arel::SelectManager)

      ast = arel.ast
      where_arel = ast.cores.first&.wheres&.first
      return unless where_arel.is_a?(Arel::Nodes::Equality)

      pk_value_attribute = where_arel.right # If this exists, it's the literal id side of WHERE <pk> = <literal id>
      pk_value = pk_value_attribute&.value # This is the actual numeric value of the literal id
      return unless pk_value

      verification_arel = where(primary_key => pk_value).limit(1).arel
      # Double check that the entire sql statement is what we expect it to be
      # by reconstructing it from the extracted parts and verifying the same arel ast.
      # If the arel of the original query wasn't SELECT <all columns> FROM <table> WHERE id = <number>
      # we return here indicating that the arel could not be replaced with the function call

      return unless verification_arel.ast == arel.ast

      function_call = Arel::Nodes::NamedFunction.new("find_#{table_name}_by_id", [pk_value_attribute]).as(table_name)
      filter_empty_row = "#{quoted_table_name}.#{connection.quote_column_name(primary_key)} IS NOT NULL"

      from(function_call).where(filter_empty_row).limit(1)
    end
  end
end
