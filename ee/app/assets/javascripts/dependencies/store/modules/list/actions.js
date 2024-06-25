import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import {
  convertObjectPropsToCamelCase,
  normalizeHeaders,
  parseIntPagination,
} from '~/lib/utils/common_utils';
import { NAMESPACE_ORGANIZATION } from 'ee/dependencies/constants';
import { __, sprintf } from '~/locale';
import pollUntilComplete from '~/lib/utils/poll_until_complete';
import download from '~/lib/utils/downloader';
import { HTTP_STATUS_CREATED } from '~/lib/utils/http_status';
import {
  DEPENDENCIES_CSV_FILENAME,
  DEPENDENCIES_FILENAME,
  FETCH_ERROR_MESSAGE,
  FETCH_ERROR_MESSAGE_WITH_DETAILS,
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

export const setNamespaceType = ({ commit }, payload) => commit(types.SET_NAMESPACE_TYPE, payload);

export const setInitialState = ({ commit }, payload) => commit(types.SET_INITIAL_STATE, payload);

export const setPageInfo = ({ commit }, payload) => commit(types.SET_PAGE_INFO, payload);

export const requestDependencies = ({ commit }) => commit(types.REQUEST_DEPENDENCIES);

const parseCursorPagination = (headers) => {
  return {
    type: headers['X-PAGE-TYPE'],
    currentCursor: headers['X-PAGE'],
    endCursor: headers['X-NEXT-PAGE'],
    hasNextPage: headers['X-NEXT-PAGE'] !== '',
    hasPreviousPage: headers['X-PREV-PAGE'] !== '',
    startCursor: headers['X-PREV-PAGE'],
  };
};

const parseOffsetPagination = (headers) => {
  return {
    ...parseIntPagination(headers),
    type: 'offset',
  };
};

const parsePagination = (headers) => {
  const paginateWithCursor = headers['X-PAGE-TYPE'] === 'cursor';
  if (paginateWithCursor) {
    return parseCursorPagination(headers);
  }
  return parseOffsetPagination(headers);
};

export const receiveDependenciesSuccess = ({ commit }, { headers, data }) => {
  const pageInfo = parsePagination(normalizeHeaders(headers));
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

const queryParametersFor = (state, params) => {
  const { searchFilterParameters } = state;
  const queryParams = {
    sort_by: state.sortField,
    sort: state.sortOrder,
    filter: state.filter,
    ...searchFilterParameters,
    ...params,
  };

  if (state.pageInfo.type === 'cursor' || (params && 'cursor' in params)) {
    queryParams.cursor = params.cursor || state.pageInfo.currentCursor;
  } else {
    queryParams.page = params?.page || state.pageInfo.page || 1;
  }

  return queryParams;
};

export const fetchDependencies = ({ state, dispatch }, params) => {
  if (!state.endpoint) {
    return;
  }

  dispatch('requestDependencies');

  axios
    .get(state.endpoint, { params: queryParametersFor(state, params) })
    .then((response) => {
      if (isValidResponse(response)) {
        dispatch('receiveDependenciesSuccess', response);
      } else {
        throw new Error(__('Invalid server response'));
      }
    })
    .catch((error) => {
      dispatch('receiveDependenciesError', error);

      const errorDetails = error?.response?.data?.message;

      const message = errorDetails
        ? sprintf(FETCH_ERROR_MESSAGE_WITH_DETAILS, { errorDetails })
        : FETCH_ERROR_MESSAGE;

      createAlert({ message });
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

const exportFilenameFor = (namespaceType) => {
  return namespaceType === NAMESPACE_ORGANIZATION
    ? DEPENDENCIES_CSV_FILENAME
    : DEPENDENCIES_FILENAME;
};

export const downloadExport = ({ state, commit }, dependencyListExportEndpoint) => {
  pollUntilComplete(dependencyListExportEndpoint)
    .then((response) => {
      if (response.data?.has_finished) {
        download({
          url: response.data?.download,
          fileName: exportFilenameFor(state?.namespaceType),
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

    // If a user types to filter available options the filter data will be a string and we just ignore it
    // as filters can only be applied via selecting an option from the dropdown
    if (!Array.isArray(filterData) || !filterData.length) {
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

export const fetchLicenses = async ({ commit, state }, licensesEndpoint) => {
  // if there are already licenses there is no need to re-fetch, as they are a static list
  if (state.licenses.length || !licensesEndpoint) {
    return;
  }

  commit(types.SET_FETCHING_LICENSES_IN_PROGRESS, true);

  try {
    const {
      data: { licenses },
    } = await axios.get(licensesEndpoint);

    const camelCasedLicensesWithId = licenses.map((license, index) =>
      // we currently don't get the id from the API, so we need to add it manually
      // this will be removed once https://gitlab.com/gitlab-org/gitlab/-/issues/439886 has been implemented
      convertObjectPropsToCamelCase({ ...license, id: index }, { deep: true }),
    );

    commit(types.SET_LICENSES, camelCasedLicensesWithId);
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

  commit(types.TOGGLE_VULNERABILITY_ITEM_LOADING, item);

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
      commit(types.TOGGLE_VULNERABILITY_ITEM_LOADING, item);
    });
};
