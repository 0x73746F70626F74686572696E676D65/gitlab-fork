# frozen_string_literal: true

FactoryBot.define do
  factory :geo_event_log, class: 'Geo::EventLog' do
    trait :created_event do
      repository_created_event factory: :geo_repository_created_event
    end

    trait :updated_event do
      repository_updated_event factory: :geo_repository_updated_event
    end

    trait :deleted_event do
      repository_deleted_event factory: :geo_repository_deleted_event
    end

    trait :renamed_event do
      repository_renamed_event factory: :geo_repository_renamed_event
    end

    trait :reset_checksum_event do
      reset_checksum_event factory: :geo_reset_checksum_event
    end

    trait :cache_invalidation_event do
      cache_invalidation_event factory: :geo_cache_invalidation_event
    end

    trait :geo_event do
      geo_event factory: :geo_event
    end
  end

  factory :geo_repository_created_event, class: 'Geo::RepositoryCreatedEvent' do
    project

    repository_storage_name { project.repository_storage }
    add_attribute(:repo_path) { project.disk_path }
    project_name { project.name }
    wiki_path { project.wiki.disk_path }
  end

  factory :geo_repository_updated_event, class: 'Geo::RepositoryUpdatedEvent' do
    project

    source { Geo::RepositoryUpdatedEvent::REPOSITORY }
    branches_affected { 0 }
    tags_affected { 0 }
  end

  factory :geo_repository_deleted_event, class: 'Geo::RepositoryDeletedEvent' do
    project

    repository_storage_name { project.repository_storage }
    deleted_path { project.full_path }
    deleted_project_name { project.name }
  end

  factory :geo_repositories_changed_event, class: 'Geo::RepositoriesChangedEvent' do
    geo_node
  end

  factory :geo_repository_renamed_event, class: 'Geo::RepositoryRenamedEvent' do
    project { association(:project, :repository) }

    repository_storage_name { project.repository_storage }
    old_path_with_namespace { project.path_with_namespace }
    new_path_with_namespace { "#{project.path_with_namespace}_new" }
    old_wiki_path_with_namespace { project.wiki.path_with_namespace }
    new_wiki_path_with_namespace { "#{project.wiki.path_with_namespace}_new" }
    old_path { project.path }
    new_path { "#{project.path}_new" }
  end

  factory :geo_reset_checksum_event, class: 'Geo::ResetChecksumEvent' do
    project
  end

  factory :geo_cache_invalidation_event, class: 'Geo::CacheInvalidationEvent' do
    sequence(:key) { |n| "cache-key-#{n}" }
  end
end
