# frozen_string_literal: true

# Usage:
#
# Seeds all groups:
#
# FILTER=ai_usage_stats bundle exec rake db:seed_fu
#
# Invoking for a single project:
#
# PROJECT_ID=22 FILTER=ai_usage_stats bundle exec rake db:seed_fu

# rubocop:disable Rails/Output -- this is a seed script
class Gitlab::Seeder::AiUsageStats # rubocop:disable Style/ClassAndModuleChildren -- this is a seed script
  CODE_PUSH_SAMPLE = 10
  AI_EVENT_COUNT_SAMPLE = 5
  TIME_PERIOD_DAYS = 90

  attr_reader :project

  def initialize(project)
    @project = project
  end

  def seed!
    create_ai_usage_data
    sync_to_click_house
  end

  def create_ai_usage_data
    project.users.count.times do
      user = project.users.sample

      CODE_PUSH_SAMPLE.times do
        Event.create!(
          project: project,
          author: user,
          action: :pushed,
          created_at: rand(TIME_PERIOD_DAYS).days.ago
        )
      end

      AI_EVENT_COUNT_SAMPLE.times do
        event_data = {
          user_id: user.id,
          event: Gitlab::Tracking::AiTracking::EVENTS['code_suggestion_shown_in_ide'],
          timestamp: rand(TIME_PERIOD_DAYS).days.ago
        }
        ClickHouse::WriteBuffer.add(Ai::CodeSuggestionsUsage.table_name, event_data)
      end
    end
  end

  def sync_to_click_house
    ClickHouse::CodeSuggestionEventsCronWorker.new.perform

    # Re-sync data with ClickHouse
    ClickHouse::SyncCursor.update_cursor_for('events', 0)
    Gitlab::ExclusiveLease.skipping_transaction_check do
      ClickHouse::EventsSyncWorker.new.perform
    end
  end
end

Gitlab::Seeder.quiet do
  feature_available = ::Gitlab::ClickHouse.globally_enabled_for_analytics?

  unless feature_available
    puts "
    WARNING:
    To use this seed file, you need to make sure that ClickHouse is configured and enabled with your GDK.
    Once you've configured the config/click_house.yml file, run the migrations:

    > bundle exec rake gitlab:clickhouse:migrate

    In a Rails console session, enable ClickHouse for analytics and the feature flags:

    Gitlab::CurrentSettings.current_application_settings.update(use_clickhouse_for_analytics: true)
    "
    break
  end

  projects = Project.all
  projects = projects.where(id: ENV['PROJECT_ID']) if ENV['PROJECT_ID']

  projects.find_each do |project|
    seeder = Gitlab::Seeder::AiUsageStats.new(project)
    seeder.seed!
  end
end
# rubocop:enable Rails/Output
