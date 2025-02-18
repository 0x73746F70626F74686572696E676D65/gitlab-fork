import { s__ } from '~/locale';
import { GENIE_CHAT_MODEL_ROLES } from 'ee/ai/constants';

export const MESSAGE_TYPES = {
  USER: GENIE_CHAT_MODEL_ROLES.user,
  TANUKI: GENIE_CHAT_MODEL_ROLES.assistant,
};

export const SOURCE_TYPES = {
  HANDBOOK: {
    value: 'handbook',
    icon: 'book',
  },
  DOC: {
    value: 'doc',
    icon: 'documents',
  },
  BLOG: {
    value: 'blog',
    icon: 'list-bulleted',
  },
};

export const ERROR_MESSAGE = s__(
  'DuoChat|There was an error communicating with GitLab Duo Chat. Please try again later.',
);

export const TANUKI_BOT_TRACKING_EVENT_NAME = 'ask_gitlab_chat';
export const TANUKI_BOT_FEEDBACK_ISSUE_URL = 'https://gitlab.com/gitlab-org/gitlab/-/issues/408527';
