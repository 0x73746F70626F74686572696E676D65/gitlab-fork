import { __, s__ } from '~/locale';

export const INPUT_DEBOUNCE = 500;

export const CUSTODY_REPORT_PARAMETER = 'commit_sha';

export const DRAWER_AVATAR_SIZE = 24;

export const DRAWER_MAXIMUM_AVATARS = 20;

export const GRAPHQL_PAGE_SIZE = 20;

const APPROVED_BY_COMMITTER = 'APPROVED_BY_COMMITTER';
const APPROVED_BY_INSUFFICIENT_USERS = 'APPROVED_BY_INSUFFICIENT_USERS';
const APPROVED_BY_MERGE_REQUEST_AUTHOR = 'APPROVED_BY_MERGE_REQUEST_AUTHOR';

export const MERGE_REQUEST_VIOLATION_MESSAGES = {
  [APPROVED_BY_COMMITTER]: s__('ComplianceReport|Approved by committer'),
  [APPROVED_BY_INSUFFICIENT_USERS]: s__('ComplianceReport|Less than 2 approvers'),
  [APPROVED_BY_MERGE_REQUEST_AUTHOR]: s__('ComplianceReport|Approved by author'),
};

export const DEFAULT_SORT = 'SEVERITY_LEVEL_DESC';

export const DEFAULT_PAGINATION_CURSORS = {
  before: null,
  after: null,
  first: GRAPHQL_PAGE_SIZE,
};

export const BRANCH_FILTER_OPTIONS = {
  allBranches: __('All branches'),
  allProtectedBranches: __('All protected branches'),
};

export const ROUTE_STANDARDS_ADHERENCE = 'standards_adherence';
export const ROUTE_VIOLATIONS = 'violations';
export const ROUTE_PROJECTS = 'projects';
export const ROUTE_FRAMEWORKS = 'frameworks';
export const ROUTE_NEW_FRAMEWORK = 'new_framework';
export const ROUTE_EDIT_FRAMEWORK = 'frameworks/:id';
export const FRAMEWORKS_LABEL_BACKGROUND = '#737278';

export const FRAMEWORKS_FILTER_TYPE_PROJECT = 'project';
export const FRAMEWORKS_FILTER_TYPE_FRAMEWORK = 'framework';
export const FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK = {
  color: '#000000',
  default: false,
  description: s__('ComplianceFrameworks|No framework'),
  id: 'gid://gitlab/ComplianceManagement::Framework/0',
  name: s__('ComplianceFrameworks|No framework'),
  pipelineConfigurationFullPath: '',
  __typename: 'ComplianceFramework',
};

export const i18n = {
  frameworksTab: s__('Compliance Center|Frameworks'),
  projectsTab: __('Projects'),
  heading: __('Compliance center'),
  standardsAdherenceTab: s__('Compliance Center|Standards Adherence'),
  subheading: __(
    'Report and manage standards adherence, violations, and compliance frameworks for the group.',
  ),
  violationsTab: s__('Compliance Center|Violations'),
};
