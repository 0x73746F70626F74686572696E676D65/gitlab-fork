import { PROMO_URL } from 'jh_else_ce/lib/utils/url_utility';
import { __, s__ } from '~/locale';

export const ADD_ON_CODE_SUGGESTIONS = 'CODE_SUGGESTIONS';
export const codeSuggestionsLearnMoreLink = `${PROMO_URL}/solutions/code-suggestions/`;
export const salesLink = `${PROMO_URL}/solutions/code-suggestions/sales/`;

export const addOnEligibleUserListTableFields = {
  codeSuggestionsAddon: {
    key: 'codeSuggestionsAddon',
    label: s__('CodeSuggestions|GitLab Duo Pro add-on'),
    thClass: 'gl-w-5/20',
    tdClass: '!gl-align-middle',
  },
  email: {
    key: 'email',
    label: __('Email'),
    thClass: 'gl-w-3/20',
    tdClass: '!gl-align-middle',
  },
  emailWide: {
    key: 'email',
    label: __('Email'),
    thClass: 'gl-w-4/20',
    tdClass: '!gl-align-middle',
  },
  lastActivityTime: {
    key: 'lastActivityTime',
    label: __('Last GitLab activity'),
    thClass: 'gl-w-3/20',
    tdClass: '!gl-align-middle',
  },
  lastActivityTimeWide: {
    key: 'lastActivityTime',
    label: __('Last GitLab activity'),
    thClass: 'gl-w-5/20',
    tdClass: '!gl-align-middle',
  },
  maxRole: {
    key: 'maxRole',
    label: __('Max role'),
    thClass: 'gl-w-3/20',
    tdClass: '!gl-align-middle',
  },
  user: {
    key: 'user',
    label: __('User'),
    thClass: `gl-pl-2! gl-w-5/20`,
    // eslint-disable-next-line @gitlab/require-i18n-strings
    tdClass: '!gl-align-middle gl-pl-2!',
  },
  checkbox: {
    key: 'checkbox',
    label: '',
    headerTitle: __('Checkbox'),
    thClass: 'gl-w-1/20 gl-pl-2!',
    // eslint-disable-next-line @gitlab/require-i18n-strings
    tdClass: '!gl-align-middle gl-pl-2!',
  },
};

export const SORT_OPTIONS = [
  {
    id: 10,
    title: __('Last activity'),
    sortDirection: {
      descending: 'LAST_ACTIVITY_ON_DESC',
      ascending: 'LAST_ACTIVITY_ON_ASC',
    },
  },
  {
    id: 20,
    title: __('Name'),
    sortDirection: {
      descending: 'NAME_DESC',
      ascending: 'NAME_ASC',
    },
  },
];

export const ASSIGN_SEATS_BULK_ACTION = 'ASSIGN_BULK_ACTION';
export const UNASSIGN_SEATS_BULK_ACTION = 'UNASSIGN_BULK_ACTION';
