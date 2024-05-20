import { __ } from '~/locale';
import { TABS as CE_TABS } from '~/members/tabs_metadata';
import PromotionRequestsTabApp from './promotion_requests/components/app.vue';
import promotionRequestsTabStore from './promotion_requests/store/index';
import { MEMBER_TYPES, TAB_QUERY_PARAM_VALUES } from './constants';

export const TABS = [
  ...CE_TABS,
  {
    namespace: MEMBER_TYPES.promotionRequest,
    title: __('Promotions'),
    queryParamValue: TAB_QUERY_PARAM_VALUES.promotionRequest,
    component: PromotionRequestsTabApp,
    store: promotionRequestsTabStore,
  },
  {
    namespace: MEMBER_TYPES.banned,
    title: __('Banned'),
    queryParamValue: TAB_QUERY_PARAM_VALUES.banned,
  },
];
