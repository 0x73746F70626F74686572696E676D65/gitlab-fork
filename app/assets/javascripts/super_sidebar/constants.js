// Note: all constants defined here are considered internal implementation
// details for the sidebar. They should not be imported by anything outside of
// the super_sidebar directory.

import Vue from 'vue';

export const SIDEBAR_PORTAL_ID = 'sidebar-portal-mount';

export const portalState = Vue.observable({
  ready: false,
});

export const SIDEBAR_VISIBILITY_CLASS = 'gl-visibility-hidden';

export const MAX_FREQUENT_PROJECTS_COUNT = 5;
export const MAX_FREQUENT_GROUPS_COUNT = 3;

export const TRACKING_UNKNOWN_ID = 'item_without_id';
export const TRACKING_UNKNOWN_PANEL = 'nav_panel_unknown';
export const CLICK_MENU_ITEM_ACTION = 'click_menu_item';

export const PANELS_WITH_PINS = ['group', 'project'];

export const USER_MENU_TRACKING_DEFAULTS = {
  'data-track-property': 'nav_user_menu',
  'data-track-action': 'click_link',
};

export const HELP_MENU_TRACKING_DEFAULTS = {
  'data-track-property': 'nav_help_menu',
  'data-track-action': 'click_link',
};
