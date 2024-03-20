# frozen_string_literal: true

module RemoteDevelopment
  module Settings
    class DefaultsInitializer
      include Messages

      UNDEFINED = nil

      # ALL REMOTE DEVELOPMENT SETTINGS MUST BE DECLARED HERE.
      # See ../README.md for more details.
      # @return [Hash]
      def self.default_settings
        {
          # NOTE: default_branch_name is not actually used by Remote Development, it is simply a placeholder to drive
          #       the logic for reading settings from ::Gitlab::CurrentSettings. It can be replaced when there is an
          #       actual Remote Development entry in ::Gitlab::CurrentSettings.
          default_branch_name: [UNDEFINED, String],
          default_max_hours_before_termination: [24, Integer],
          max_hours_before_termination_limit: [120, Integer],
          project_cloner_image: ['alpine/git:2.36.3', String],
          tools_injector_image: ["registry.gitlab.com/gitlab-org/gitlab-web-ide-vscode-fork/web-ide-injector:9", String]
        }
      end

      # @param [Hash] value
      # @return [Hash]
      # @raise [RuntimeError]
      def self.init(value)
        value[:settings] = {}
        value[:setting_types] = {}

        default_settings.each do |setting_name, setting_value_and_type|
          unless setting_value_and_type.is_a?(Array) && setting_value_and_type.length == 2
            raise "Remote Development Setting entry for '#{setting_name}' must " \
              "be a two-element array containing the value and type." # rubocop:disable Layout/LineEndStringConcatenationIndentation -- This is being changed in https://gitlab.com/gitlab-org/ruby/gems/gitlab-styles/-/merge_requests/212
          end

          setting_value, setting_type = setting_value_and_type

          unless setting_type.is_a?(Class)
            raise "Remote Development Setting type for '#{setting_name}' " \
              "must be a class, but it was a #{setting_type.class}." # rubocop:disable Layout/LineEndStringConcatenationIndentation -- This is being changed in https://gitlab.com/gitlab-org/ruby/gems/gitlab-styles/-/merge_requests/212
          end

          if !setting_value.nil? && !setting_value.is_a?(setting_type)
            # NOTE: We are raising an exception here instead of returning a Result.err, because this is
            # a coding syntax error in the 'default_settings', not a user or data error.
            raise "Remote Development Setting '#{setting_name}' has a type of '#{setting_value.class}', " \
              "which does not match declared type of '#{setting_type}'." # rubocop:disable Layout/LineEndStringConcatenationIndentation -- This is being changed in https://gitlab.com/gitlab-org/ruby/gems/gitlab-styles/-/merge_requests/212
          end

          value[:settings][setting_name] = setting_value
          value[:setting_types][setting_name] = setting_type
        end

        value
      end
    end
  end
end
