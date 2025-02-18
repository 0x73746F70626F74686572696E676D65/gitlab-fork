import Vue from 'vue';
import initSamlGroupLinkRoleSelector from 'ee/saml_group_links/saml_group_link_role_selector';
import GroupSelect from './components/group_select.vue';

export default () => {
  const el = document.getElementById('js-ldap-groups-select');
  const providerElement = document.getElementById('ldap_group_link_provider');

  if (!el) {
    return null;
  }

  return new Vue({
    el,
    render(createElement) {
      return createElement(GroupSelect, {
        props: { providerElement },
      });
    },
  });
};

initSamlGroupLinkRoleSelector();
