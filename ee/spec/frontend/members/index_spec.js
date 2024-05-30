import { MEMBERS_TAB_TYPES } from 'ee/members/constants';
import promotionRequestsTabStore from 'ee/members/promotion_requests/store';
import { dataAttribute } from 'ee_jest/members/mock_data';
import { initMembersApp } from '~/members/index';
import { parseDataAttributes } from '~/members/utils';

jest.mock('ee/members/promotion_requests/store');
promotionRequestsTabStore.mockImplementation(
  jest.requireActual('ee/members/promotion_requests/store').default,
);

describe('initMembersApp', () => {
  /** @type {HTMLDivElement} */
  let el;
  let vm;

  const setup = () => {
    vm = initMembersApp(el, {
      [MEMBERS_TAB_TYPES.user]: {},
      [MEMBERS_TAB_TYPES.promotionRequest]: {},
    });
  };

  beforeEach(() => {
    el = document.createElement('div');
    el.dataset.membersData = dataAttribute;
  });

  afterEach(() => {
    el = null;
  });

  it('sets `disableTwoFactorPath` in Vuex store', () => {
    setup();

    expect(vm.$store.state[MEMBERS_TAB_TYPES.user].disableTwoFactorPath).toBe(
      '/groups/ldap-group/-/two_factor_auth',
    );
  });

  it('sets `ldapOverridePath` in Vuex store', () => {
    setup();

    expect(vm.$store.state[MEMBERS_TAB_TYPES.user].ldapOverridePath).toBe(
      '/groups/ldap-group/-/group_members/:id/override',
    );
  });

  describe('Promotion requests Vuex store', () => {
    it('inits promotion requests store with proper props', () => {
      const parsedData = parseDataAttributes(el);
      setup();

      expect(promotionRequestsTabStore).toHaveBeenCalledWith(
        parsedData[MEMBERS_TAB_TYPES.promotionRequest],
      );
    });
  });
});
