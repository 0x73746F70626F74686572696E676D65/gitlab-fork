import { pick } from 'lodash';
import { __, s__ } from '~/locale';

export const SORT_FIELD_NAME = 'name';
export const SORT_FIELD_PACKAGER = 'packager';
export const SORT_FIELD_SEVERITY = 'severity';
export const SORT_FIELD_LICENSE = 'license';

const SORT_FIELDS = {
  [SORT_FIELD_NAME]: s__('Dependencies|Component name'),
  [SORT_FIELD_PACKAGER]: s__('Dependencies|Packager'),
  [SORT_FIELD_SEVERITY]: s__('Vulnerability|Severity'),
  [SORT_FIELD_LICENSE]: s__('Dependencies|License'),
};

export const SORT_FIELDS_PROJECT = pick(SORT_FIELDS, [
  SORT_FIELD_NAME,
  SORT_FIELD_PACKAGER,
  SORT_FIELD_SEVERITY,
]);

export const SORT_FIELDS_GROUP = pick(SORT_FIELDS, [
  SORT_FIELD_NAME,
  SORT_FIELD_PACKAGER,
  SORT_FIELD_LICENSE,
  SORT_FIELD_SEVERITY,
]);

export const SORT_ASCENDING = 'asc';
export const SORT_DESCENDING = 'desc';

export const SORT_ORDERS = {
  [SORT_FIELD_NAME]: SORT_ASCENDING,
  [SORT_FIELD_PACKAGER]: SORT_ASCENDING,
  [SORT_FIELD_SEVERITY]: SORT_DESCENDING,
  [SORT_FIELD_LICENSE]: SORT_DESCENDING,
};

export const REPORT_STATUS = {
  ok: 'ok',
  jobNotSetUp: 'job_not_set_up',
  jobFailed: 'job_failed',
  noDependencies: 'no_dependencies',
  incomplete: 'no_dependency_files',
};

export const FILTER = {
  all: 'all',
  vulnerable: 'vulnerable',
};

export const FETCH_ERROR_MESSAGE = __(
  'Error fetching the dependency list. Please check your network connection and try again.',
);

export const FETCH_ERROR_MESSAGE_WITH_DETAILS = __(
  'Error fetching the dependency list: %{errorDetails}',
);

export const FETCH_EXPORT_ERROR_MESSAGE = s__(
  'Dependencies|Error exporting the dependency list. Please reload the page.',
);

export const DEPENDENCIES_FILENAME = 'dependencies.json';
export const DEPENDENCIES_CSV_FILENAME = 'dependencies.csv';

export const LICENSES_FETCH_ERROR_MESSAGE = s__(
  'Dependencies|There was a problem fetching the licenses for this group.',
);

export const VULNERABILITIES_FETCH_ERROR_MESSAGE = s__(
  'Dependencies|There was a problem fetching vulnerabilities.',
);
