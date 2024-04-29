import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import StatusToken from './status_token.vue';
import ActivityToken from './activity_token.vue';
import SeverityToken from './severity_token.vue';
import ToolToken from './tool_token.vue';
import ImageToken from './image_token.vue';

export const STATUS_TOKEN_DEFINITION = {
  type: 'state',
  title: StatusToken.i18n.statusLabel,
  multiSelect: true,
  unique: true,
  token: StatusToken,
  operators: OPERATORS_OR,
};

export const ACTIVITY_TOKEN_DEFINITION = {
  type: 'activity',
  title: ActivityToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ActivityToken,
  operators: OPERATORS_OR,
};

export const SEVERITY_TOKEN_DEFINITION = {
  type: 'severity',
  title: SeverityToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: SeverityToken,
  operators: OPERATORS_OR,
};

export const TOOL_VENDOR_TOKEN_DEFINITION = {
  type: 'scanner',
  title: ToolToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ToolToken,
  operators: OPERATORS_OR,
};

export const IMAGE_TOKEN_DEFINITION = {
  type: 'image',
  title: ImageToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: ImageToken,
  operators: OPERATORS_OR,
};
