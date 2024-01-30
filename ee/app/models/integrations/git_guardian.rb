# frozen_string_literal: true

module Integrations
  class GitGuardian < Integration
    validates :token, presence: true, if: :activated?

    field :token,
      type: :password,
      title: 'API token',
      help: -> { s_('GitGuardian|Personal access token to authenticate calls to the GitGuardian API.') },
      non_empty_password_title: -> { s_('ProjectService|Enter new API token') },
      non_empty_password_help: -> { s_('ProjectService|Leave blank to use your current API token.') },
      placeholder: 'Fc6d9dcf3Ab...',
      required: true

    def self.title
      'GitGuardian'
    end

    def self.description
      s_('GitGuardian|Scan pushed document contents for policy breaks.')
    end

    def self.to_param
      'git_guardian'
    end

    def self.supported_events
      []
    end

    def execute(blobs)
      return unless Feature.enabled?(:git_guardian_integration, type: :wip)

      ::Gitlab::GitGuardian::Client.new(token).execute(blobs) if activated?
    end

    def testable?
      false
    end
  end
end
