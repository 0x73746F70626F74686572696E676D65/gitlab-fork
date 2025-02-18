import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlTableLite } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import PromotionRequestsApp from 'ee/members/promotion_requests/components/app.vue';
import { MEMBERS_TAB_TYPES, TAB_QUERY_PARAM_VALUES } from 'ee_else_ce/members/constants';
import initStore from 'ee/members/promotion_requests/store/index';
import MembersPagination from '~/members/components/table/members_pagination.vue';
import UserAvatar from '~/members/components/avatars/user_avatar.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import { data as mockData, pagination as mockPagination } from '../mock_data';

describe('PromotionRequestsApp', () => {
  Vue.use(Vuex);

  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = ({ pagination = mockPagination } = {}) => {
    const store = new Vuex.Store({
      modules: {
        [MEMBERS_TAB_TYPES.promotionRequest]: initStore({ data: mockData, pagination }),
      },
    });

    wrapper = mountExtended(PromotionRequestsApp, {
      propsData: {
        namespace: MEMBERS_TAB_TYPES.promotionRequest,
        tabQueryParamValue: TAB_QUERY_PARAM_VALUES.promotionRequest,
      },
      provide: { canManageMembers: false },
      store,
    });

    return nextTick();
  };

  const findTable = () => wrapper.findComponent(GlTableLite);

  beforeEach(async () => {
    await createComponent();
  });

  describe('renders pending promotion users table', () => {
    it('renders the table with rows corresponding to mocked data', () => {
      expect(findTable().exists()).toBe(true);

      expect(findTable().findAll('tbody > tr').length).toEqual(mockData.length);
    });

    it('renders the mocked data properly inside a row', () => {
      const columns = findTable().findAll('tbody > tr').at(0).findAll('td');
      expect(columns.at(0).findComponent(UserAvatar).exists()).toBe(true);
      expect(columns.at(0).findComponent(UserAvatar).props('member')).toMatchObject(mockData[0]);
      expect(columns.at(1).text()).toBe(mockData[0].newAccessLevel.stringValue);
      expect(columns.at(2).text()).toBe(mockData[0].requestedBy.name);
      expect(columns.at(3).findComponent(UserDate).exists()).toBe(true);
      expect(columns.at(3).findComponent(UserDate).props('date')).toBe(mockData[0].createdAt);
    });
  });

  it('renders `members-pagination` component with correct props', () => {
    const membersPagination = wrapper.findComponent(MembersPagination);

    expect(membersPagination.props()).toEqual({
      pagination: mockPagination,
      tabQueryParamValue: TAB_QUERY_PARAM_VALUES.promotionRequest,
    });
  });
});
