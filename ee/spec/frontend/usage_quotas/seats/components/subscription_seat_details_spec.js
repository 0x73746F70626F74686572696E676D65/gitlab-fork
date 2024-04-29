import { GlTableLite, GlBadge } from '@gitlab/ui';
import { shallowMount, mount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { cloneDeep } from 'lodash';
import SubscriptionSeatDetails from 'ee/usage_quotas/seats/components/subscription_seat_details.vue';
import SubscriptionSeatDetailsLoader from 'ee/usage_quotas/seats/components/subscription_seat_details_loader.vue';
import createStore from 'ee/usage_quotas/seats/store';
import initState from 'ee/usage_quotas/seats/store/state';
import { mockMemberDetails } from 'ee_jest/usage_quotas/seats/mock_data';
import { stubComponent } from 'helpers/stub_component';

Vue.use(Vuex);

describe('SubscriptionSeatDetails', () => {
  let wrapper;
  const actions = {
    fetchBillableMemberDetails: jest.fn(),
  };

  const createComponent = ({ initialUserDetails, mountFn = shallowMount } = {}) => {
    const seatMemberId = 1;
    const store = createStore(initState({ namespaceId: 1 }));
    store.state = {
      ...store.state,
      userDetails: {
        [seatMemberId]: {
          isLoading: false,
          hasError: false,
          items: mockMemberDetails,
          ...initialUserDetails,
        },
      },
    };

    wrapper = mountFn(SubscriptionSeatDetails, {
      propsData: {
        seatMemberId,
      },
      store: new Vuex.Store({ ...store, actions }),
      stubs: mountFn === shallowMount ? { GlTableLite: stubComponent(GlTableLite) } : {},
    });
  };

  const findRoleCell = () => wrapper.find('tbody td:nth-child(4)');

  describe('on created', () => {
    beforeEach(() => {
      createComponent();
    });

    it('calls fetchBillableMemberDetails', () => {
      expect(actions.fetchBillableMemberDetails).toHaveBeenCalledWith(expect.any(Object), 1);
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent({
        initialUserDetails: {
          isLoading: true,
        },
      });
    });

    it('displays skeleton loader', () => {
      expect(wrapper.findComponent(SubscriptionSeatDetailsLoader).isVisible()).toBe(true);
    });
  });

  describe('error state', () => {
    beforeEach(() => {
      createComponent({
        initialUserDetails: {
          isLoading: false,
          hasError: true,
        },
      });
    });

    it('displays skeleton loader', () => {
      expect(wrapper.findComponent(SubscriptionSeatDetailsLoader).isVisible()).toBe(true);
    });
  });

  describe('membership role', () => {
    it('shows base role if there is no custom role', () => {
      createComponent({ mountFn: mount });

      expect(findRoleCell().text()).toBe('Owner');
    });

    describe('when there is a custom role', () => {
      beforeEach(() => {
        const items = cloneDeep(mockMemberDetails);
        items[0].access_level.custom_role = { id: 1, name: 'Custom role name' };

        createComponent({ mountFn: mount, initialUserDetails: { items } });
      });

      it('shows custom role name', () => {
        expect(findRoleCell().text()).toContain('Custom role name');
      });

      it('shows custom role badge', () => {
        expect(wrapper.findComponent(GlBadge).text()).toBe('Custom role');
      });
    });
  });
});
