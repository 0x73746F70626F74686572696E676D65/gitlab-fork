# frozen_string_literal: true

module Search
  module Zoekt
    module TestHelpers
      def ensure_zoekt_node!
        index_base_url = ENV.fetch('ZOEKT_INDEX_BASE_URL', 'http://127.0.0.1:6060')
        search_base_url = ENV.fetch('ZOEKT_SEARCH_BASE_URL', 'http://127.0.0.1:6070')
        ::Search::Zoekt::Node.find_or_create_by!(
          index_base_url: index_base_url,
          search_base_url: search_base_url
        ) do |node|
          node.uuid = SecureRandom.uuid
        end
      end
      module_function :ensure_zoekt_node!

      def zoekt_node
        ensure_zoekt_node!
      end
      module_function :zoekt_node

      def zoekt_truncate_index!
        ::Gitlab::Search::Zoekt::Client.truncate
      end
      module_function :zoekt_truncate_index!

      def zoekt_ensure_namespace_indexed!(namespace)
        root_namespace = namespace.root_ancestor
        zoekt_enabled_namespace = ::Search::Zoekt::EnabledNamespace.find_or_create_by!(namespace: root_namespace)
        index = ::Search::Zoekt::Index.find_or_create_by!(zoekt_enabled_namespace: zoekt_enabled_namespace,
          node: zoekt_node,
          namespace_id: root_namespace.id,
          replica: Replica.for_enabled_namespace!(zoekt_enabled_namespace))
        index.update!(state: :ready)
      end

      def zoekt_ensure_project_indexed!(project)
        zoekt_ensure_namespace_indexed!(project.namespace)

        project.repository.update_zoekt_index!
        # Add delay to allow Zoekt wbeserver to finish the indexing
        10.times do
          results = Gitlab::Search::Zoekt::Client.new.search('.*', num: 1, project_ids: [project.id],
            node_id: zoekt_node.id, search_mode: :regex)
          break if results.file_count > 0

          sleep 0.01
        end
      end
    end
  end

  RSpec.configure do |config|
    config.before do
      # This feature flag is by default disabled and should be used to disable Zoekt search for SaaS customers on demand
      stub_feature_flags(disable_zoekt_search_for_saas: false)
    end

    config.around(:each, :zoekt) do |example|
      node = Search::Zoekt::TestHelpers.ensure_zoekt_node!
      node.backoff.remove_backoff!

      Search::Zoekt::TestHelpers.zoekt_truncate_index!

      example.run

      Search::Zoekt::TestHelpers.zoekt_truncate_index!
    end

    config.before(:each, :zoekt) do
      stub_licensed_features(zoekt_code_search: true)
    end

    config.before(:each, :zoekt_settings_enabled) do
      stub_ee_application_setting(zoekt_indexing_enabled: true, zoekt_search_enabled: true)
    end

    config.include Search::Zoekt::TestHelpers
  end
end
