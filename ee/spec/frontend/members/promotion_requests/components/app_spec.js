import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import PromotionRequestsApp from 'ee/members/promotion_requests/components/app.vue';
import { MEMBER_TYPES, TAB_QUERY_PARAM_VALUES } from 'ee_else_ce/members/constants';
import initStore from 'ee/members/promotion_requests/store/index';
import MembersPagination from '~/members/components/table/members_pagination.vue';
import { data as mockData, pagination as mockPagination } from '../mock_data';

describe('PromotionRequestsApp', () => {
  Vue.use(Vuex);

  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = ({ pagination = mockPagination } = {}) => {
    const store = new Vuex.Store({
      modules: {
        [MEMBER_TYPES.promotionRequest]: initStore({ data: mockData, pagination }),
      },
    });

    wrapper = mountExtended(PromotionRequestsApp, {
      propsData: {
        namespace: MEMBER_TYPES.promotionRequest,
        tabQueryParamValue: TAB_QUERY_PARAM_VALUES.promotionRequest,
      },
      store,
    });

    return nextTick();
  };

  beforeEach(async () => {
    await createComponent();
  });

  it('will render the list of users pending promotion', () => {
    const list = wrapper.findAll('li');
    expect(list.length).toBe(mockData.length);
    expect(wrapper.text()).toContain(mockData[0].user.name);
  });

  it('renders `members-pagination` component with correct props', () => {
    const membersPagination = wrapper.findComponent(MembersPagination);

    expect(membersPagination.props()).toEqual({
      pagination: mockPagination,
      tabQueryParamValue: TAB_QUERY_PARAM_VALUES.promotionRequest,
    });
  });
});
