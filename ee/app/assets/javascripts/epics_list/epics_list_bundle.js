import Vue from 'vue';
import VueApollo from 'vue-apollo';

import { STATUS_OPEN } from '~/issues/constants';
import { apolloProvider } from '~/graphql_shared/issuable_client';
import { parseBoolean, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { queryToObject } from '~/lib/utils/url_utility';

import EpicsListApp from './components/epics_list_root.vue';

Vue.use(VueApollo);

export default function initEpicsList({ mountPointSelector }) {
  const mountPointEl = document.querySelector(mountPointSelector);

  if (!mountPointEl) {
    return null;
  }

  const {
    page = 1,
    prev = '',
    next = '',
    initialState = STATUS_OPEN,
    initialSortBy = 'start_date_desc',
    canCreateEpic,
    canBulkEditEpics,
    hasScopedLabelsFeature,
    epicNewPath,
    listEpicsPath,
    groupFullPath,
    labelsManagePath,
    labelsFetchPath,
    groupMilestonesPath,
    emptyStatePath,
    isSignedIn,
    hasIssuableHealthStatusFeature,
  } = mountPointEl.dataset;

  const rawFilterParams = queryToObject(window.location.search, { gatherArrays: true });
  const initialFilterParams = {
    ...convertObjectPropsToCamelCase(rawFilterParams, {
      dropKeys: ['scope', 'utf8', 'state', 'sort'], // These keys are unsupported/unnecessary
    }),
    // We shall put parsed value of `confidential` only
    // when it is defined.
    ...(rawFilterParams.confidential && {
      confidential: parseBoolean(rawFilterParams.confidential),
    }),
  };

  return new Vue({
    el: mountPointEl,
    name: 'EpicsListRoot',
    apolloProvider,
    provide: {
      initialState,
      initialSortBy,
      prev,
      next,
      page: parseInt(page, 10),
      canCreateEpic: parseBoolean(canCreateEpic),
      canBulkEditEpics: parseBoolean(canBulkEditEpics),
      hasScopedLabelsFeature: parseBoolean(hasScopedLabelsFeature),
      labelsFetchPath: `${labelsFetchPath}?only_group_labels=true`,
      hasIssuableHealthStatusFeature: parseBoolean(hasIssuableHealthStatusFeature),
      epicNewPath,
      listEpicsPath,
      groupFullPath,
      fullPath: groupFullPath,
      labelsManagePath,
      groupMilestonesPath,
      emptyStatePath,
      isSignedIn: parseBoolean(isSignedIn),
      isGroup: true,
    },
    render: (createElement) =>
      createElement(EpicsListApp, {
        props: {
          initialFilterParams,
        },
      }),
  });
}
