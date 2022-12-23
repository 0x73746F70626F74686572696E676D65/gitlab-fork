# frozen_string_literal: true

module Gitlab
  module Ci
    module Variables
      class Collection
        include Enumerable

        attr_reader :errors

        def initialize(variables = [], errors = nil)
          @variables = []
          @variables_by_key = Hash.new { |h, k| h[k] = [] }
          @errors = errors

          variables.each { |variable| self.append(variable) }
        end

        def append(resource)
          item = Collection::Item.fabricate(resource)
          @variables.append(item)
          @variables_by_key[item[:key]] << item

          self
        end

        def compact
          Collection.new(select { |variable| !variable.value.nil? })
        end

        def concat(resources)
          return self if resources.nil?

          tap { resources.each { |variable| self.append(variable) } }
        end

        def each
          @variables.each { |variable| yield variable }
        end

        def +(other)
          self.class.new.tap do |collection|
            self.each { |variable| collection.append(variable) }
            other.each { |variable| collection.append(variable) }
          end
        end

        def [](key)
          all(key)&.last
        end

        def all(key)
          vars = @variables_by_key[key]
          vars unless vars.empty?
        end

        def size
          @variables.size
        end

        def to_runner_variables
          self.map(&:to_runner_variable)
        end

        def to_hash
          self.to_runner_variables
            .to_h { |env| [env.fetch(:key), env.fetch(:value)] }
            .with_indifferent_access
        end

        def reject(&block)
          Collection.new(@variables.reject(&block))
        end

        # `expand_raw_refs` will be deleted with the FF `ci_raw_variables_in_yaml_config`.
        def expand_value(value, keep_undefined: false, expand_file_refs: true, expand_raw_refs: true)
          value.gsub(Item::VARIABLES_REGEXP) do
            match = Regexp.last_match # it is either a valid variable definition or a ($$ / %%)
            full_match = match[0]
            variable_name = match[:key]

            next full_match unless variable_name # it is a ($$ / %%), so we don't touch it

            # now we know that it is a valid variable definition: $VARIABLE_NAME / %VARIABLE_NAME / ${VARIABLE_NAME}

            # we are trying to find a variable with key VARIABLE_NAME
            variable = self[variable_name]

            if variable # VARIABLE_NAME is an existing variable
              if variable.file?
                expand_file_refs ? variable.value : full_match
              elsif variable.raw?
                # With `full_match`, we defer the expansion of raw variables to the runner. If we expand them here,
                # the runner will not know the expanded value is a raw variable and it tries to expand it again.
                # Discussion: https://gitlab.com/gitlab-org/gitlab/-/issues/353991#note_1103274951
                expand_raw_refs ? variable.value : full_match
              else
                variable.value
              end

            elsif keep_undefined
              full_match # we do not touch the variable definition
            else
              nil # we remove the variable definition
            end
          end
        end

        # `expand_raw_refs` will be deleted with the FF `ci_raw_variables_in_yaml_config`.
        def sort_and_expand_all(keep_undefined: false, expand_file_refs: true, expand_raw_refs: true)
          sorted = Sort.new(self)
          return self.class.new(self, sorted.errors) unless sorted.valid?

          new_collection = self.class.new

          sorted.tsort.each do |item|
            unless item.depends_on
              new_collection.append(item)
              next
            end

            # expand variables as they are added
            variable = item.to_runner_variable
            variable[:value] = new_collection.expand_value(variable[:value], keep_undefined: keep_undefined,
                                                                             expand_file_refs: expand_file_refs,
                                                                             expand_raw_refs: expand_raw_refs)
            new_collection.append(variable)
          end

          new_collection
        end

        def to_s
          "#{@variables_by_key.keys}, @errors='#{@errors}'"
        end

        protected

        attr_reader :variables
      end
    end
  end
end
