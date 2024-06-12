import { WORKSPACE_STATES } from '../common/constants';

export {
  I18N_LOADING_WORKSPACES_FAILED,
  WORKSPACES_LIST_PAGE_SIZE,
  WORKSPACES_LIST_POLL_INTERVAL,
} from '../common/constants';

export const ROUTES = {
  index: 'index',
  new: 'new',
};

export const PROJECT_VISIBILITY = {
  public: 'public',
  private: 'private',
  internal: 'internal',
};

export const DEFAULT_DESIRED_STATE = WORKSPACE_STATES.running;
export const DEFAULT_DEVFILE_PATH = '.devfile.yaml';
export const DEFAULT_EDITOR = 'webide';

export const WORKSPACE_VARIABLE_INPUT_TYPE_ENUM = {
  env: 'ENVIRONMENT',
};
