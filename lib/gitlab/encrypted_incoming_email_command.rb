# frozen_string_literal: true

# rubocop:disable Rails/Output
module Gitlab
  class EncryptedIncomingEmailCommand < EncryptedCommandBase
    DISPLAY_NAME = "INCOMING_EMAIL"
    EDIT_COMMAND_NAME = "gitlab:incoming_email:secret:edit"

    class << self
      def encrypted_secrets
        Gitlab::IncomingEmail.encrypted_secrets
      end

      def encrypted_file_template
        <<~YAML
          # password: '123'
          # user: 'gitlab-incoming@gmail.com'
        YAML
      end
    end
  end
end
# rubocop:enable Rails/Output
