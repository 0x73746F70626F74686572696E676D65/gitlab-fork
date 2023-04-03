import { __, s__ } from '~/locale';

export const DRAWER_CONTAINER_CLASS = '.content-wrapper';

export const JOB_RULES_WHEN = {
  onSuccess: {
    value: 'on_success',
    text: s__('JobAssistant|on_success'),
  },
  onFailure: {
    value: 'on_failure',
    text: s__('JobAssistant|on_failure'),
  },
  manual: {
    value: 'manual',
    text: s__('JobAssistant|manual'),
  },
  always: {
    value: 'always',
    text: s__('JobAssistant|always'),
  },
  delayed: {
    value: 'delayed',
    text: s__('JobAssistant|delayed'),
  },
  never: {
    value: 'never',
    text: s__('JobAssistant|never'),
  },
};

export const JOB_RULES_START_IN = {
  second: {
    value: 'second',
    text: s__('JobAssistant|second(s)'),
  },
  minute: {
    value: 'minute',
    text: s__('JobAssistant|minute(s)'),
  },
  day: {
    value: 'day',
    text: s__('JobAssistant|day(s)'),
  },
  week: {
    value: 'week',
    text: s__('JobAssistant|week(s)'),
  },
};

export const SECONDS_MULTIPLE_MAP = {
  second: 1,
  minute: 60,
  day: 3600 * 24,
  week: 3600 * 24 * 7,
};

export const JOB_TEMPLATE = {
  name: '',
  stage: '',
  script: '',
  tags: [],
  image: {
    name: '',
    entrypoint: [''],
  },
  services: [
    {
      name: '',
      entrypoint: [''],
    },
  ],
  artifacts: {
    paths: [''],
    exclude: [''],
  },
  cache: {
    paths: [''],
    key: '',
  },
  rules: [
    {
      allow_failure: false,
      when: 'on_success',
      start_in: '',
    },
  ],
};

export const i18n = {
  ADD_JOB: s__('JobAssistant|Add job'),
  SCRIPT: s__('JobAssistant|Script'),
  JOB_NAME: s__('JobAssistant|Job name'),
  JOB_SETUP: s__('JobAssistant|Job Setup'),
  STAGE: s__('JobAssistant|Stage (optional)'),
  TAGS: s__('JobAssistant|Tags (optional)'),
  IMAGE: s__('JobAssistant|Image'),
  IMAGE_NAME: s__('JobAssistant|Image name (optional)'),
  IMAGE_ENTRYPOINT: s__('JobAssistant|Image entrypoint (optional)'),
  THIS_FIELD_IS_REQUIRED: __('This field is required'),
  CACHE_PATHS: s__('JobAssistant|Cache paths (optional)'),
  CACHE_KEY: s__('JobAssistant|Cache key (optional)'),
  ARTIFACTS_EXCLUDE_PATHS: s__('JobAssistant|Artifacts exclude paths (optional)'),
  ARTIFACTS_PATHS: s__('JobAssistant|Artifacts paths (optional)'),
  ARTIFACTS_AND_CACHE: s__('JobAssistant|Artifacts and cache'),
  ADD_PATH: s__('JobAssistant|Add path'),
  RULES: s__('JobAssistant|Rules'),
  WHEN: s__('JobAssistant|When'),
  ALLOW_FAILURE: s__('JobAssistant|Allow failure'),
  INVALID_START_IN: s__('JobAssistant|Error - Valid value is between 1 second and 1 week'),
};
