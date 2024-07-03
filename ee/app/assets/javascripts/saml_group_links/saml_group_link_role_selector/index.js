import Vue from 'vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import SamlGroupLinkRoleSelector from './components/saml_group_link_role_selector.vue';

export default () => {
  const el = document.querySelector('.js-saml-group-link-role-selector');

  if (!el) {
    return null;
  }

  const {
    samlGroupLinkRoleSelectorData = {},
    baseAccessLevelInputName,
    memberRoleIdInputName,
  } = el.dataset;
  const { standardRoles, customRoles = [] } = convertObjectPropsToCamelCase(
    JSON.parse(samlGroupLinkRoleSelectorData),
    { deep: true },
  );

  return new Vue({
    el,
    name: 'SamlGroupLinkRoleSelectorRoot',
    provide: {
      standardRoles,
      customRoles,
    },
    render(h) {
      return h(SamlGroupLinkRoleSelector, {
        props: {
          baseAccessLevelInputName,
          memberRoleIdInputName,
        },
      });
    },
  });
};
