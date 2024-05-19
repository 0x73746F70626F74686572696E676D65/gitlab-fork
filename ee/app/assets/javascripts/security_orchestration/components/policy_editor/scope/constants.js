import { s__ } from '~/locale';

export const PROJECTS_WITH_FRAMEWORK = 'projects_with_framework';
export const ALL_PROJECTS_IN_GROUP = 'all_projects_in_group';
export const SPECIFIC_PROJECTS = 'specific_projects';

export const PROJECT_SCOPE_TYPE_TEXTS = {
  [PROJECTS_WITH_FRAMEWORK]: s__('SecurityOrchestration|projects with compliance frameworks'),
  [ALL_PROJECTS_IN_GROUP]: s__('SecurityOrchestration|all subgroups/projects in this group'),
  [SPECIFIC_PROJECTS]: s__('SecurityOrchestration|specific projects'),
};

const mapToListBoxItems = (textMap) =>
  Object.entries(textMap).map(([value, text]) => ({
    value,
    text,
  }));

export const PROJECT_SCOPE_TYPE_LISTBOX_ITEMS = mapToListBoxItems(PROJECT_SCOPE_TYPE_TEXTS);

export const WITHOUT_EXCEPTIONS = 'without_exceptions';
export const EXCEPT_PROJECTS = 'except_projects';
export const INCLUDING = 'including';
export const EXCLUDING = 'excluding';
export const COMPLIANCE_FRAMEWORKS_KEY = 'compliance_frameworks';
export const PROJECTS_KEY = 'projects';

export const EXCEPTION_TYPE_TEXTS = {
  [WITHOUT_EXCEPTIONS]: s__('SecurityOrchestration|without exceptions'),
  [EXCEPT_PROJECTS]: s__('SecurityOrchestration|except projects'),
};

export const EXCEPTION_TYPE_LISTBOX_ITEMS = mapToListBoxItems(EXCEPTION_TYPE_TEXTS);
