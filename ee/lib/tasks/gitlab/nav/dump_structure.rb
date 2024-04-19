# frozen_string_literal: true

module Tasks
  module Gitlab
    module Nav
      class DumpStructure
        attr_accessor :context_defaults

        def initialize
          @context_defaults = {
            current_user: User.first,
            is_super_sidebar: true,

            # Turn features on that impact the list of items rendered
            can_view_pipeline_editor: true,
            learn_gitlab_enabled: true,
            show_discover_group_security: true,
            show_discover_project_security: true,
            show_security_dashboard: true,

            # Turn features off that do not add/remove items
            show_cluster_hint: false,
            show_promotions: false,

            current_ref: 'master'
          }
        end

        def panels
          panels = []
          panels << Sidebars::UserProfile::Panel.new(Sidebars::Context.new(
            container: User.first,
            **@context_defaults
          ))
          panels << Sidebars::UserSettings::Panel.new(Sidebars::Context.new(
            container: User.first,
            **@context_defaults
          ))
          panels << Sidebars::YourWork::Panel.new(Sidebars::Context.new(
            container: User.first,
            **@context_defaults
          ))
          panels << Sidebars::Projects::SuperSidebarPanel.new(Sidebars::Projects::Context.new(
            container: Project.first,
            **@context_defaults
          ))
          panels << Sidebars::Groups::SuperSidebarPanel.new(Sidebars::Groups::Context.new(
            container: Group.first,
            **@context_defaults
          ))
          panels << Sidebars::Organizations::Panel.new(Sidebars::Context.new(
            container: Organizations::Organization.first,
            **@context_defaults
          ))
          panels << Sidebars::Admin::Panel.new(Sidebars::Context.new(
            container: nil,
            **@context_defaults
          ))
          panels << Sidebars::Explore::Panel.new(Sidebars::Context.new(
            container: nil,
            **@context_defaults
          ))

          panels
        end

        def current_time
          Time.now.utc.iso8601
        end

        def current_sha
          `git rev-parse --short HEAD`.strip
        end

        def dump
          contexts = panels.map do |panel|
            {
              title: panel.aria_label,
              items: panel.super_sidebar_menu_items
            }
          end

          # Recurse through structure to drop info we don't need
          clean_keys!(contexts)

          YAML.dump({
            generated_at: current_time,
            commit_sha: current_sha,
            contexts: contexts
          }.deep_stringify_keys)
        end

        private

        def clean_keys!(entries)
          entries.each do |entry|
            clean_keys!(entry[:items]) if entry[:items]

            entry[:id] = entry[:id].to_s if entry[:id]
            entry.slice!(:id, :title, :icon, :link, :items)
          end
        end
      end
    end
  end
end
