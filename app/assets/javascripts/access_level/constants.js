import { __ } from '~/locale';

// Matches `lib/gitlab/access.rb`
export const ACCESS_LEVEL_NO_ACCESS_INTEGER = 0;
export const ACCESS_LEVEL_MINIMAL_ACCESS_INTEGER = 5;
export const ACCESS_LEVEL_GUEST_INTEGER = 10;
export const ACCESS_LEVEL_REPORTER_INTEGER = 20;
export const ACCESS_LEVEL_DEVELOPER_INTEGER = 30;
export const ACCESS_LEVEL_MAINTAINER_INTEGER = 40;
export const ACCESS_LEVEL_OWNER_INTEGER = 50;
export const ACCESS_LEVEL_ADMIN_INTEGER = 60;

const ACCESS_LEVEL_NO_ACCESS = __('No access');
const ACCESS_LEVEL_MINIMAL_ACCESS = __('Minimal Access');
const ACCESS_LEVEL_GUEST = __('Guest');
const ACCESS_LEVEL_REPORTER = __('Reporter');
const ACCESS_LEVEL_DEVELOPER = __('Developer');
const ACCESS_LEVEL_MAINTAINER = __('Maintainer');
const ACCESS_LEVEL_OWNER = __('Owner');

export const BASE_ROLES = [
  { value: 'GUEST', text: ACCESS_LEVEL_GUEST },
  { value: 'REPORTER', text: ACCESS_LEVEL_REPORTER },
  { value: 'DEVELOPER', text: ACCESS_LEVEL_DEVELOPER },
  { value: 'MAINTAINER', text: ACCESS_LEVEL_MAINTAINER },
  { value: 'OWNER', text: ACCESS_LEVEL_OWNER },
];

export const BASE_ROLES_INC_MINIMAL_ACCESS = [
  { value: 'MINIMAL_ACCESS', text: ACCESS_LEVEL_MINIMAL_ACCESS },
  ...BASE_ROLES,
];

export const ACCESS_LEVEL_LABELS = {
  [ACCESS_LEVEL_NO_ACCESS_INTEGER]: ACCESS_LEVEL_NO_ACCESS,
  [ACCESS_LEVEL_MINIMAL_ACCESS_INTEGER]: ACCESS_LEVEL_MINIMAL_ACCESS,
  [ACCESS_LEVEL_GUEST_INTEGER]: ACCESS_LEVEL_GUEST,
  [ACCESS_LEVEL_REPORTER_INTEGER]: ACCESS_LEVEL_REPORTER,
  [ACCESS_LEVEL_DEVELOPER_INTEGER]: ACCESS_LEVEL_DEVELOPER,
  [ACCESS_LEVEL_MAINTAINER_INTEGER]: ACCESS_LEVEL_MAINTAINER,
  [ACCESS_LEVEL_OWNER_INTEGER]: ACCESS_LEVEL_OWNER,
};

export const ACCESS_LEVEL_INTEGERS = {
  MINIMAL_ACCESS: ACCESS_LEVEL_MINIMAL_ACCESS_INTEGER,
  GUEST: ACCESS_LEVEL_GUEST_INTEGER,
  REPORTER: ACCESS_LEVEL_REPORTER_INTEGER,
  DEVELOPER: ACCESS_LEVEL_DEVELOPER_INTEGER,
  MAINTAINER: ACCESS_LEVEL_MAINTAINER_INTEGER,
  OWNER: ACCESS_LEVEL_OWNER_INTEGER,
};
