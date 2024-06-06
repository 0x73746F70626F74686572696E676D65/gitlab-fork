# frozen_string_literal: true

module Admin
  module ApplicationSettingsHelper
    def ai_powered_testing_agreement
      safe_format(
        s_('AIPoweredSM|By enabling this feature, you agree to the %{link_start}GitLab Testing Agreement%{link_end}.'),
        tag_pair_for_link(gitlab_testing_agreement_url))
    end

    def ai_powered_description
      safe_format(
        s_('AIPoweredSM|Enable %{link_start}AI-powered features%{link_end} for this instance.'),
        tag_pair_for_link(ai_powered_docs_url))
    end

    def admin_display_ai_powered_toggle?
      License.feature_available?(:ai_chat) && CloudConnector::AvailableServices.find_by_name(:duo_chat).free_access?
    end

    private

    # rubocop:disable Gitlab/DocUrl
    # We want to link SaaS docs for flexibility for every URL related to Code Suggestions on Self Managed.
    # We expect to update docs often during the Beta and we want to point user to the most up to date information.
    def ai_powered_docs_url
      'https://docs.gitlab.com/ee/user/ai_features.html'
    end

    def gitlab_testing_agreement_url
      'https://about.gitlab.com/handbook/legal/testing-agreement/'
    end
    # rubocop:enable Gitlab/DocUrl

    def tag_pair_for_link(url)
      tag_pair(link_to('', url, target: '_blank', rel: 'noopener noreferrer'), :link_start, :link_end)
    end
  end
end
