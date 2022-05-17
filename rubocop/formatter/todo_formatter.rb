# frozen_string_literal: true

require 'set'
require 'rubocop'
require 'yaml'

require_relative '../todo_dir'

module RuboCop
  module Formatter
    # This formatter dumps a YAML configuration file per cop rule
    # into `.rubocop_todo/**/*.yml` which contains detected offenses.
    #
    # For example, this formatter stores offenses for `RSpec/VariableName`
    # in `.rubocop_todo/rspec/variable_name.yml`.
    class TodoFormatter < BaseFormatter
      class Todo
        attr_reader :cop_name, :files, :offense_count

        def initialize(cop_name)
          @cop_name = cop_name
          @files = Set.new
          @offense_count = 0
          @cop_class = RuboCop::Cop::Registry.global.find_by_cop_name(cop_name)
        end

        def record(file, offense_count)
          @files << file
          @offense_count += offense_count
        end

        def autocorrectable?
          @cop_class&.support_autocorrect?
        end
      end

      DEFAULT_BASE_DIRECTORY = File.expand_path('../../.rubocop_todo', __dir__)

      class << self
        attr_accessor :base_directory
      end

      self.base_directory = DEFAULT_BASE_DIRECTORY

      def initialize(output, _options = {})
        @directory = self.class.base_directory
        @todos = Hash.new { |hash, cop_name| hash[cop_name] = Todo.new(cop_name) }
        @todo_dir = TodoDir.new(directory)
        @config_inspect_todo_dir = load_config_inspect_todo_dir
        @config_old_todo_yml = load_config_old_todo_yml
        check_multiple_configurations!

        super
      end

      def file_finished(file, offenses)
        return if offenses.empty?

        file = relative_path(file)

        offenses.map(&:cop_name).tally.each do |cop_name, offense_count|
          @todos[cop_name].record(file, offense_count)
        end
      end

      def finished(_inspected_files)
        @todos.values.sort_by(&:cop_name).each do |todo|
          yaml = to_yaml(todo)
          path = @todo_dir.write(todo.cop_name, yaml)

          output.puts "Written to #{relative_path(path)}\n"
        end
      end

      def self.with_base_directory(directory)
        old = base_directory
        self.base_directory = directory

        yield
      ensure
        self.base_directory = old
      end

      private

      attr_reader :directory

      def relative_path(path)
        parent = File.expand_path('..', directory)
        path.delete_prefix("#{parent}/")
      end

      def to_yaml(todo)
        yaml = []
        yaml << '---'
        yaml << '# Cop supports --auto-correct.' if todo.autocorrectable?
        yaml << "#{todo.cop_name}:"

        if previously_disabled?(todo)
          yaml << "  # Offense count: #{todo.offense_count}"
          yaml << '  # Temporarily disabled due to too many offenses'
          yaml << '  Enabled: false'
        end

        yaml << '  Exclude:'

        files = todo.files.sort.map { |file| "    - '#{file}'" }
        yaml.concat files
        yaml << ''

        yaml.join("\n")
      end

      def check_multiple_configurations!
        cop_names = @config_inspect_todo_dir.keys & @config_old_todo_yml.keys
        return if cop_names.empty?

        list = cop_names.sort.map { |cop_name| "- #{cop_name}" }.join("\n")
        raise "Multiple configurations found for cops:\n#{list}\n"
      end

      def previously_disabled?(todo)
        cop_name = todo.cop_name

        config = @config_old_todo_yml[cop_name] ||
          @config_inspect_todo_dir[cop_name] || {}
        return false if config.empty?

        config['Enabled'] == false
      end

      def load_config_inspect_todo_dir
        @todo_dir.list_inspect.each_with_object({}) do |path, combined|
          config = YAML.load_file(path)
          combined.update(config) if Hash === config
        end
      end

      # Load YAML configuration from `.rubocop_todo.yml`.
      # We consider this file already old, obsolete, and to be removed soon.
      def load_config_old_todo_yml
        path = File.expand_path(File.join(directory, '../.rubocop_todo.yml'))
        config = YAML.load_file(path) if File.exist?(path)

        config || {}
      end
    end
  end
end
