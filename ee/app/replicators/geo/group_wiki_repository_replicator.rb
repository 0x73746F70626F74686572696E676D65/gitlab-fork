# frozen_string_literal: true

module Geo
  class GroupWikiRepositoryReplicator < Gitlab::Geo::Replicator
    include ::Geo::RepositoryReplicatorStrategy

    def self.model
      ::GroupWikiRepository
    end

    def self.git_access_class
      ::Gitlab::GitAccessWiki
    end

    def self.no_repo_message
      git_access_class.error_message(:no_group_repo)
    end

    override :verification_feature_flag_enabled?
    def self.verification_feature_flag_enabled?
      true
    end

    override :housekeeping_enabled?
    def self.housekeeping_enabled?
      false
    end

    override :verify
    def verify
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/426571
      unless repository.exists?
        log_error(
          "Git repository of group wiki was not found. To avoid verification error, creating empty Git repository",
          nil,
          {
            group_wiki_repository_id: model_record.id,
            group_id: model_record.group_id
          }
        )

        model_record.create_wiki
      end

      super
    end

    def repository
      model_record.repository
    end
  end
end
