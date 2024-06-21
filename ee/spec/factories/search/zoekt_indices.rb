# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_index, class: '::Search::Zoekt::Index' do
    zoekt_enabled_namespace { association(:zoekt_enabled_namespace) }
    node { association(:zoekt_node) }
    replica { association(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace) }
    namespace_id { zoekt_enabled_namespace.root_namespace_id }
  end

  trait :ready do
    state { ::Search::Zoekt::Index.state_value(:ready) }
  end
end
