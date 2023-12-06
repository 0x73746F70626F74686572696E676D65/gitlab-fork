# frozen_string_literal: true

namespace :gitlab do
  namespace :duo do
    desc 'GitLab | Duo | Enable GitLab Duo features on the specified group'
    task :setup, [:root_group_path] => :environment do |_, args|
      Gitlab::Duo::Developments::Setup.new(args).execute
    end

    desc 'GitLab | Duo | Enable GitLab Duo feature flags'
    task enable_feature_flags: :gitlab_environment do
      Gitlab::Duo::Developments::FeatureFlagEnabler.execute
    end
  end
end
