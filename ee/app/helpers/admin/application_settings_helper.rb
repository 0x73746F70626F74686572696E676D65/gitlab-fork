# frozen_string_literal: true

module Admin
  module ApplicationSettingsHelper
    # rubocop:disable Layout/LineLength
    # rubocop:disable Style/FormatString
    # rubocop:disable Rails/OutputSafety
    # We extracted Code Suggestions tooltips/texts generation to this helper from the views, to make them lightweight.
    # Rubocop would not consider LineLength, FormatString, OutputSafety problematic if it stayed in the view.
    # We decided that it is worth extracting this logic here and silencing Rubocop just for code_suggestions_* helpers.
    def ai_powered_testing_agreement
      terms_link_start = ai_powered_link_start(gitlab_testing_agreement_url)

      s_('AIPoweredSM|By enabling this feature, you agree to the %{terms_link_start}GitLab Testing Agreement%{link_end}.')
        .html_safe % { terms_link_start: terms_link_start, link_end: '</a>'.html_safe }
    end

    def ai_powered_description
      link_start = ai_powered_link_start(ai_powered_docs_url)

      s_('AIPoweredSM|Enable %{link_start}AI-powered features%{link_end} for this instance.')
        .html_safe % { link_start: link_start, link_end: '</a>'.html_safe }
    end
    # rubocop:enable Layout/LineLength
    # rubocop:enable Style/FormatString
    # rubocop:enable Rails/OutputSafety

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

    # rubocop:disable Rails/OutputSafety
    def ai_powered_link_start(url)
      "<a href=\"#{url}\" target=\"_blank\" rel=\"noopener noreferrer\">".html_safe
    end
    # rubocop:enable Rails/OutputSafety
  end
end
