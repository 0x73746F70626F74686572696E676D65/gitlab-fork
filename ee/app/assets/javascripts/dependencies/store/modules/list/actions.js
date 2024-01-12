import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import {
  convertObjectPropsToCamelCase,
  normalizeHeaders,
  parseIntPagination,
} from '~/lib/utils/common_utils';
import { __ } from '~/locale';
import pollUntilComplete from '~/lib/utils/poll_until_complete';
import download from '~/lib/utils/downloader';
import { HTTP_STATUS_CREATED } from '~/lib/utils/http_status';
import {
  DEPENDENCIES_FILENAME,
  FETCH_ERROR_MESSAGE,
  FETCH_EXPORT_ERROR_MESSAGE,
  LICENSES_FETCH_ERROR_MESSAGE,
  VULNERABILITIES_FETCH_ERROR_MESSAGE,
} from './constants';
import * as types from './mutation_types';
import { isValidResponse } from './utils';

export const setDependenciesEndpoint = ({ commit }, endpoint) =>
  commit(types.SET_DEPENDENCIES_ENDPOINT, endpoint);

export const setExportDependenciesEndpoint = ({ commit }, payload) =>
  commit(types.SET_EXPORT_DEPENDENCIES_ENDPOINT, payload);

export const setInitialState = ({ commit }, payload) => commit(types.SET_INITIAL_STATE, payload);

export const requestDependencies = ({ commit }) => commit(types.REQUEST_DEPENDENCIES);

export const receiveDependenciesSuccess = ({ commit }, { headers, data }) => {
  const normalizedHeaders = normalizeHeaders(headers);
  const pageInfo = parseIntPagination(normalizedHeaders);
  const { dependencies, report: reportInfo } = data;
  const convertedDependencies = dependencies.map((item) =>
    convertObjectPropsToCamelCase(item, {
      deep: true,
    }),
  );

  commit(types.RECEIVE_DEPENDENCIES_SUCCESS, {
    dependencies: convertedDependencies,
    reportInfo,
    pageInfo,
  });
};

export const receiveDependenciesError = ({ commit }, error) =>
  commit(types.RECEIVE_DEPENDENCIES_ERROR, error);

export const fetchDependencies = ({ state, dispatch }, params) => {
  if (!state.endpoint) {
    return;
  }

  const { searchFilterParameters } = state;

  dispatch('requestDependencies');

  axios
    .get(state.endpoint, {
      params: {
        sort_by: state.sortField,
        sort: state.sortOrder,
        page: state.pageInfo.page || 1,
        filter: state.filter,
        ...searchFilterParameters,
        ...params,
      },
    })
    .then((response) => {
      if (isValidResponse(response)) {
        dispatch('receiveDependenciesSuccess', response);
      } else {
        throw new Error(__('Invalid server response'));
      }
    })
    .catch((error) => {
      dispatch('receiveDependenciesError', error);
      createAlert({
        message: FETCH_ERROR_MESSAGE,
      });
    });
};

export const setSortField = ({ commit, dispatch }, id) => {
  commit(types.SET_SORT_FIELD, id);
  dispatch('fetchDependencies', { page: 1 });
};

export const toggleSortOrder = ({ commit, dispatch }) => {
  commit(types.TOGGLE_SORT_ORDER);
  dispatch('fetchDependencies', { page: 1 });
};

export const fetchExport = ({ state, commit, dispatch }) => {
  if (!state.exportEndpoint) {
    return;
  }

  commit(types.SET_FETCHING_IN_PROGRESS, true);

  axios
    .post(state.exportEndpoint)
    .then((response) => {
      if (response?.status === HTTP_STATUS_CREATED) {
        dispatch('downloadExport', response?.data?.self);
      } else {
        throw new Error(__('Invalid server response'));
      }
    })
    .catch(() => {
      commit(types.SET_FETCHING_IN_PROGRESS, false);
      createAlert({
        message: FETCH_EXPORT_ERROR_MESSAGE,
      });
    });
};

export const downloadExport = ({ commit }, dependencyListExportEndpoint) => {
  pollUntilComplete(dependencyListExportEndpoint)
    .then((response) => {
      if (response.data?.has_finished) {
        download({
          url: response.data?.download,
          fileName: DEPENDENCIES_FILENAME,
        });
      }
    })
    .catch(() => {
      createAlert({
        message: FETCH_EXPORT_ERROR_MESSAGE,
      });
    })
    .finally(() => {
      commit(types.SET_FETCHING_IN_PROGRESS, false);
    });
};

export const setSearchFilterParameters = ({ state, commit }, searchFilters = []) => {
  const searchFilterParameters = {};

  // populate the searchFilterParameters object with the data from the search filters. For example:
  // given filters: [{ type: 'licenses', value: { data: ['MIT', 'GNU'] } }, { type: 'project', value: { data: ['GitLab'] } }
  // will result in the parameters: { licenses: ['MIT', 'GNU'], project: ['GitLab'] }
  searchFilters.forEach((searchFilter) => {
    let filterData = searchFilter.value.data;

    if (!filterData?.length) {
      return;
    }

    if (searchFilter.type === 'licenses') {
      // for the license filter we display the license name in the UI, but want to send the spdx-identifier to the API
      const getSpdxIdentifier = (licenseName) =>
        state.licenses.find(({ name }) => name === licenseName)?.spdxIdentifier || [];

      filterData = filterData.flatMap(getSpdxIdentifier);
    }

    searchFilterParameters[searchFilter.type] = filterData;
  });

  commit(types.SET_SEARCH_FILTER_PARAMETERS, searchFilterParameters);
};

export const fetchLicenses = async ({ commit }, licensesEndpoint) => {
  if (!licensesEndpoint) {
    return;
  }

  commit(types.SET_FETCHING_LICENSES_IN_PROGRESS, true);

  try {
    const {
      data: { licenses },
    } = await axios.get(licensesEndpoint);

    const camelCasedLicenses = licenses.map((license) =>
      convertObjectPropsToCamelCase(license, { deep: true }),
    );

    commit(types.SET_LICENSES, camelCasedLicenses);
  } catch (e) {
    createAlert({
      message: LICENSES_FETCH_ERROR_MESSAGE,
    });
  } finally {
    commit(types.SET_FETCHING_LICENSES_IN_PROGRESS, false);
  }
};

export const fetchVulnerabilities = ({ commit }, { item, vulnerabilitiesEndpoint }) => {
  if (!vulnerabilitiesEndpoint) {
    return;
  }

  commit(types.SET_VULNERABILITY_ITEM, item);

  axios
    .get(vulnerabilitiesEndpoint, {
      params: {
        id: item.occurrenceId,
      },
    })
    .then(({ data }) => {
      commit(types.SET_VULNERABILITIES, data);
    })
    .catch(() => {
      createAlert({
        message: VULNERABILITIES_FETCH_ERROR_MESSAGE,
      });
    })
    .finally(() => {
      commit(types.SET_VULNERABILITY_ITEM, null);
    });
};
