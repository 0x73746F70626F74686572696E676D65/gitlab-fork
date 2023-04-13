import { s__, sprintf } from '~/locale';

export const i18n = {
  GENIE_TOOLTIP: s__('AI|What does the selected code mean?'),
  GENIE_NO_CONTAINER_ERROR: s__("AI|The container element wasn't found, stopping AI Genie."),
  GENIE_CHAT_TITLE: s__('AI|Code Explanation'),
  GENIE_CHAT_CLOSE_LABEL: s__('AI|Close the Code Explanation'),
  GENIE_CHAT_LEGAL_NOTICE: sprintf(
    s__(
      'AI|You are not allowed to copy any part of this output into issues, comments, GitLab source code, commit messages, merge requests or any other user interface in the %{gitlabOrg} or %{gitlabCom} groups.',
    ),
    { gitlabOrg: '<code>/gitlab-org</code>', gitlabCom: '<code>/gitlab-com</code>' },
    false,
  ),
};
export const AI_GENIE_DEBOUNCE = 300;
