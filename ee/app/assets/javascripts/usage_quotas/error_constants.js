import { s__ } from '~/locale';
import { PROMO_URL } from 'jh_else_ce/lib/utils/url_utility';
import { convertObjectPropsToLowerCase } from '~/lib/utils/common_utils';

const salesLink = `${PROMO_URL}/solutions/code-suggestions/sales/`;
const supportLink = `${PROMO_URL}/support/`;

const NO_SEATS_AVAILABLE_ERROR = {
  title: s__('Billing|No seats available'),
  message: s__(
    'Billing|You have assigned all available GitLab Duo Pro add-on seats. Please %{salesLinkStart}contact sales%{salesLinkEnd} if you would like to purchase more seats.',
  ),
  links: { salesLink },
};

const GENERAL_ADD_ON_ASSIGNMENT_ERROR = {
  title: s__('Billing|Error assigning GitLab Duo Pro add-on'),
  message: s__(
    'Billing|Something went wrong when assigning the add-on to this member. If the problem persists, please %{supportLinkStart}contact support%{supportLinkEnd}.',
  ),
  links: { supportLink },
};

const GENERAL_ADD_ON_UNASSIGNMENT_ERROR = {
  title: s__('Billing|Error un-assigning GitLab Duo Pro add-on'),
  message: s__(
    'Billing|Something went wrong when un-assigning the add-on to this member. If the problem persists, please %{supportLinkStart}contact support%{supportLinkEnd}.',
  ),
  links: { supportLink },
};

const NOT_ENOUGH_SEATS_ERROR = {
  title: s__('Billing|Not enough seats'),
  message: s__(
    'Billing|There are not enough seats to assign the GitLab Duo Pro add-on to all selected members. To purchase more seats for your subscription, please %{salesLinkStart}contact sales%{salesLinkEnd}.',
  ),
  links: { salesLink },
};

const GENERAL_ADD_ON_BULK_ASSIGNMENT_ERROR = {
  title: s__('Billing|Error assigning GitLab Duo Pro add-on'),
  message: s__(
    'Billing|Something went wrong when assigning the add-on for the selected members. If the problem persists, please %{supportLinkStart}contact support%{supportLinkEnd}.',
  ),
  links: { supportLink },
};

const GENERAL_ADD_ON_BULK_UNASSIGNMENT_ERROR = {
  title: s__('Billing|Error unassigning GitLab Duo Pro add-on'),
  message: s__(
    'Billing|Something went wrong when unassigning the add-on to the selected members. If the problem persists, please %{supportLinkStart}contact support%{supportLinkEnd}.',
  ),
  links: { supportLink },
};

export const ADDON_PURCHASE_FETCH_ERROR = {
  message: s__(
    'Billing|An error occurred while loading details for the GitLab Duo Pro add-on. If the problem persists, please %{supportLinkStart}contact support%{supportLinkEnd}.',
  ),
  links: { supportLink },
};

export const ADD_ON_ELIGIBLE_USERS_FETCH_ERROR = {
  message: s__(
    'Billing|An error occurred while loading users of the GitLab Duo Pro add-on. If the problem persists, please %{supportLinkStart}contact support%{supportLinkEnd}.',
  ),
  links: { supportLink },
};

const NO_SEATS_AVAILABLE_ERROR_CODE = 'NO_SEATS_AVAILABLE';
export const CANNOT_ASSIGN_ADDON_ERROR_CODE = 'CANNOT_ASSIGN_ADDON';
export const CANNOT_UNASSIGN_ADDON_ERROR_CODE = 'CANNOT_UNASSIGN_ADDON';
export const NO_ASSIGNMENTS_FOUND_ERROR_CODE = 'NO_ASSIGNMENTS_FOUND';
const NOT_ENOUGH_SEATS_ERROR_CODE = 'NOT_ENOUGH_SEATS';
export const CANNOT_BULK_ASSIGN_ADDON_ERROR_CODE = 'CANNOT_BULK_ASSIGN_ADDON';
export const CANNOT_BULK_UNASSIGN_ADDON_ERROR_CODE = 'CANNOT_BULK_UNASSIGN_ADDON';
export const ADD_ON_PURCHASE_FETCH_ERROR_CODE = 'ADD_ON_PURCHASE_FETCH_ERROR';
export const ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE = 'ADD_ON_ELIGIBLE_USERS_FETCH_ERROR';

export const ADD_ON_ERROR_DICTIONARY = convertObjectPropsToLowerCase({
  [NO_SEATS_AVAILABLE_ERROR_CODE]: NO_SEATS_AVAILABLE_ERROR,
  [CANNOT_ASSIGN_ADDON_ERROR_CODE]: GENERAL_ADD_ON_ASSIGNMENT_ERROR,
  [CANNOT_UNASSIGN_ADDON_ERROR_CODE]: GENERAL_ADD_ON_UNASSIGNMENT_ERROR,
  [NOT_ENOUGH_SEATS_ERROR_CODE]: NOT_ENOUGH_SEATS_ERROR,
  [CANNOT_BULK_ASSIGN_ADDON_ERROR_CODE]: GENERAL_ADD_ON_BULK_ASSIGNMENT_ERROR,
  [CANNOT_BULK_UNASSIGN_ADDON_ERROR_CODE]: GENERAL_ADD_ON_BULK_UNASSIGNMENT_ERROR,
  [ADD_ON_PURCHASE_FETCH_ERROR_CODE]: ADDON_PURCHASE_FETCH_ERROR,
  [ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE]: ADD_ON_ELIGIBLE_USERS_FETCH_ERROR,
});
