import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import { sortBy } from 'lodash';
import * as actions from 'ee/dependencies/store/modules/list/actions';
import {
  NAMESPACE_ORGANIZATION,
  NAMESPACE_GROUP,
  NAMESPACE_PROJECT,
} from 'ee/dependencies/constants';
import {
  FILTER,
  SORT_DESCENDING,
  FETCH_EXPORT_ERROR_MESSAGE,
  DEPENDENCIES_CSV_FILENAME,
  DEPENDENCIES_FILENAME,
  LICENSES_FETCH_ERROR_MESSAGE,
  VULNERABILITIES_FETCH_ERROR_MESSAGE,
} from 'ee/dependencies/store/modules/list/constants';
import * as types from 'ee/dependencies/store/modules/list/mutation_types';
import getInitialState from 'ee/dependencies/store/modules/list/state';
import { TEST_HOST } from 'helpers/test_constants';
import testAction from 'helpers/vuex_action_helper';
import { createAlert } from '~/alert';
import download from '~/lib/utils/downloader';
import {
  HTTP_STATUS_CREATED,
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
  HTTP_STATUS_NOT_FOUND,
  HTTP_STATUS_OK,
} from '~/lib/utils/http_status';

import mockDependenciesResponse from './data/mock_dependencies.json';

jest.mock('~/alert');
jest.mock('~/lib/utils/downloader');

describe('Dependencies actions', () => {
  const pageInfo = {
    page: 3,
    nextPage: 2,
    previousPage: 1,
    perPage: 20,
    total: 100,
    totalPages: 5,
    type: 'offset',
  };

  const headers = {
    'X-Next-Page': pageInfo.nextPage,
    'X-Page': pageInfo.page,
    'X-Per-Page': pageInfo.perPage,
    'X-Prev-Page': pageInfo.previousPage,
    'X-Total': pageInfo.total,
    'X-Total-Pages': pageInfo.totalPages,
  };

  const cursorHeaders = {
    'X-Next-Page': 'eyJpZCI6IjYyIiwiX2tkIjoibiJ9',
    'X-Page': 'eyJpZCI6IjQyIiwiX2tkIjoibiJ9',
    'X-Page-Type': 'cursor',
    'X-Per-Page': 20,
    'X-Prev-Page': 'eyJpZCI6IjQyIiwiX2tkIjoicCJ9',
  };

  const mockResponseExportEndpoint = {
    id: 1,
    has_finished: true,
    self: '/dependency_list_exports/1',
    download: '/dependency_list_exports/1/download',
  };

  afterEach(() => {
    createAlert.mockClear();
    download.mockClear();
  });

  describe('setDependenciesEndpoint', () => {
    it('commits the SET_DEPENDENCIES_ENDPOINT mutation', () =>
      testAction(
        actions.setDependenciesEndpoint,
        TEST_HOST,
        getInitialState(),
        [
          {
            type: types.SET_DEPENDENCIES_ENDPOINT,
            payload: TEST_HOST,
          },
        ],
        [],
      ));
  });

  describe('setExportDependenciesEndpoint', () => {
    it('commits the SET_EXPORT_DEPENDENCIES_ENDPOINT mutation', () =>
      testAction(
        actions.setExportDependenciesEndpoint,
        TEST_HOST,
        getInitialState(),
        [
          {
            type: types.SET_EXPORT_DEPENDENCIES_ENDPOINT,
            payload: TEST_HOST,
          },
        ],
        [],
      ));
  });

  describe('setInitialState', () => {
    it('commits the SET_INITIAL_STATE mutation', () => {
      const payload = { filter: 'foo' };

      return testAction(
        actions.setInitialState,
        payload,
        getInitialState(),
        [
          {
            type: types.SET_INITIAL_STATE,
            payload,
          },
        ],
        [],
      );
    });
  });

  describe('requestDependencies', () => {
    it('commits the REQUEST_DEPENDENCIES mutation', () =>
      testAction(
        actions.requestDependencies,
        undefined,
        getInitialState(),
        [
          {
            type: types.REQUEST_DEPENDENCIES,
          },
        ],
        [],
      ));
  });

  describe('receiveDependenciesSuccess', () => {
    it('commits the RECEIVE_DEPENDENCIES_SUCCESS mutation', () =>
      testAction(
        actions.receiveDependenciesSuccess,
        { headers, data: mockDependenciesResponse },
        getInitialState(),
        [
          {
            type: types.RECEIVE_DEPENDENCIES_SUCCESS,
            payload: {
              dependencies: mockDependenciesResponse.dependencies,
              reportInfo: mockDependenciesResponse.report,
              pageInfo,
            },
          },
        ],
        [],
      ));

    describe('with cursor pagination headers', () => {
      it('commits the correct pagination info', () => {
        testAction(
          actions.receiveDependenciesSuccess,
          {
            headers: cursorHeaders,
            data: mockDependenciesResponse,
          },
          getInitialState(),
          [
            {
              type: types.RECEIVE_DEPENDENCIES_SUCCESS,
              payload: {
                dependencies: mockDependenciesResponse.dependencies,
                reportInfo: mockDependenciesResponse.report,
                pageInfo: {
                  type: 'cursor',
                  currentCursor: cursorHeaders['X-Page'],
                  endCursor: cursorHeaders['X-Next-Page'],
                  hasNextPage: true,
                  hasPreviousPage: true,
                  startCursor: cursorHeaders['X-Prev-Page'],
                },
              },
            },
          ],
          [],
        );
      });
    });
  });

  describe('receiveDependenciesError', () => {
    it('commits the RECEIVE_DEPENDENCIES_ERROR mutation', () => {
      const error = { error: true };

      return testAction(
        actions.receiveDependenciesError,
        error,
        getInitialState(),
        [
          {
            type: types.RECEIVE_DEPENDENCIES_ERROR,
            payload: error,
          },
        ],
        [],
      );
    });
  });

  describe('fetchDependencies', () => {
    const dependenciesPackagerDescending = {
      ...mockDependenciesResponse,
      dependencies: sortBy(mockDependenciesResponse.dependencies, 'packager').reverse(),
    };

    let state;
    let mock;

    beforeEach(() => {
      state = getInitialState();
      state.endpoint = `${TEST_HOST}/dependencies`;
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('when endpoint is empty', () => {
      beforeEach(() => {
        state.endpoint = '';
      });

      it('does nothing', () => testAction(actions.fetchDependencies, undefined, state, [], []));
    });

    describe('on success', () => {
      describe('given only page param', () => {
        beforeEach(() => {
          state.pageInfo = { ...pageInfo };

          const paramsDefault = {
            sort_by: state.sortField,
            sort: state.sortOrder,
            page: state.pageInfo.page,
            filter: state.filter,
          };

          mock
            .onGet(state.endpoint, { params: paramsDefault })
            .replyOnce(HTTP_STATUS_OK, mockDependenciesResponse, headers);
        });

        it('uses default sorting params from state', () =>
          testAction(
            actions.fetchDependencies,
            { page: state.pageInfo.page },
            state,
            [],
            [
              {
                type: 'requestDependencies',
              },
              {
                type: 'receiveDependenciesSuccess',
                payload: expect.objectContaining({ data: mockDependenciesResponse, headers }),
              },
            ],
          ));
      });

      describe('with cursor pagination', () => {
        beforeEach(() => {
          state.pageInfo = {
            type: 'cursor',
            currentCursor: cursorHeaders['X-Page'],
            endCursor: cursorHeaders['X-Next-Page'],
            hasNextPage: true,
            hasPreviousPage: true,
            startCursor: cursorHeaders['X-Prev-Page'],
          };

          const expectedParams = {
            sort_by: state.sortField,
            sort: state.sortOrder,
            filter: state.filter,
            cursor: state.pageInfo.currentCursor,
          };

          mock
            .onGet(state.endpoint, { params: expectedParams })
            .replyOnce(HTTP_STATUS_OK, mockDependenciesResponse, cursorHeaders);
        });

        it('fetches the results for the current cursor', () => {
          testAction(
            actions.fetchDependencies,
            { cursor: state.pageInfo.currentCursor },
            state,
            [],
            [
              {
                type: 'requestDependencies',
              },
              {
                type: 'receiveDependenciesSuccess',
                payload: expect.objectContaining({
                  data: mockDependenciesResponse,
                  headers: cursorHeaders,
                }),
              },
            ],
          );
        });
      });

      describe('given params', () => {
        const paramsGiven = {
          sort_by: 'packager',
          sort: SORT_DESCENDING,
          page: 4,
          filter: FILTER.vulnerable,
        };

        beforeEach(() => {
          mock
            .onGet(state.endpoint, { params: paramsGiven })
            .replyOnce(HTTP_STATUS_OK, dependenciesPackagerDescending, headers);
        });

        it('overrides default params', () =>
          testAction(
            actions.fetchDependencies,
            paramsGiven,
            state,
            [],
            [
              {
                type: 'requestDependencies',
              },
              {
                type: 'receiveDependenciesSuccess',
                payload: expect.objectContaining({ data: dependenciesPackagerDescending, headers }),
              },
            ],
          ));
      });

      describe('given params with cursor', () => {
        const paramsGiven = {
          sort_by: 'packager',
          sort: SORT_DESCENDING,
          filter: FILTER.vulnerable,
          cursor: 'eyJpZCI6IjQzIiwiX2tkIjoibiJ9Cg%2b%2b',
        };

        beforeEach(() => {
          mock
            .onGet(state.endpoint, { params: paramsGiven })
            .replyOnce(HTTP_STATUS_OK, dependenciesPackagerDescending, headers);
        });

        it('overrides default params', () =>
          testAction(
            actions.fetchDependencies,
            paramsGiven,
            state,
            [],
            [
              {
                type: 'requestDependencies',
              },
              {
                type: 'receiveDependenciesSuccess',
                payload: expect.objectContaining({ data: dependenciesPackagerDescending, headers }),
              },
            ],
          ));
      });
    });

    describe.each`
      responseType                         | responseDetails                                                             | expectedErrorMessage
      ${'invalid response'}                | ${[HTTP_STATUS_OK, { foo: 'bar' }]}                                         | ${'Error fetching the dependency list. Please check your network connection and try again.'}
      ${'a response error'}                | ${[HTTP_STATUS_INTERNAL_SERVER_ERROR]}                                      | ${'Error fetching the dependency list. Please check your network connection and try again.'}
      ${'a response error with a message'} | ${[HTTP_STATUS_INTERNAL_SERVER_ERROR, { message: 'Custom error message' }]} | ${'Error fetching the dependency list: Custom error message'}
    `('given $responseType', ({ responseDetails, expectedErrorMessage }) => {
      beforeEach(() => {
        mock.onGet(state.endpoint).replyOnce(...responseDetails);
      });

      it('dispatches the receiveDependenciesError action and creates an alert', () =>
        testAction(
          actions.fetchDependencies,
          undefined,
          state,
          [],
          [
            {
              type: 'requestDependencies',
            },
            {
              type: 'receiveDependenciesError',
              payload: expect.any(Error),
            },
          ],
        ).then(() => {
          expect(createAlert).toHaveBeenCalledTimes(1);
          expect(createAlert).toHaveBeenCalledWith({
            message: expectedErrorMessage,
          });
        }));
    });
  });

  describe('fetchExport', () => {
    let state;
    let mock;

    beforeEach(() => {
      state = getInitialState();
      state.exportEndpoint = `${TEST_HOST}/dependency_list_exports`;
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('when endpoint is empty', () => {
      beforeEach(() => {
        state.exportEndpoint = '';
      });

      it('does nothing', () => testAction(actions.fetchExport, undefined, state, [], []));
    });

    describe('on success', () => {
      beforeEach(() => {
        mock
          .onPost(state.exportEndpoint)
          .replyOnce(HTTP_STATUS_CREATED, mockResponseExportEndpoint);
      });

      it('sets SET_FETCHING_IN_PROGRESS and dispatches downloadExport', () =>
        testAction(
          actions.fetchExport,
          undefined,
          state,
          [
            {
              type: 'SET_FETCHING_IN_PROGRESS',
              payload: true,
            },
          ],
          [
            {
              type: 'downloadExport',
              payload: mockResponseExportEndpoint.self,
            },
          ],
        ));
    });

    describe('on success with status other than created (201)', () => {
      beforeEach(() => {
        mock.onPost(state.exportEndpoint).replyOnce(HTTP_STATUS_OK, mockResponseExportEndpoint);
      });

      it('does not dispatch downloadExport', () =>
        testAction(
          actions.fetchExport,
          undefined,
          state,
          [
            {
              type: 'SET_FETCHING_IN_PROGRESS',
              payload: true,
            },
            {
              type: 'SET_FETCHING_IN_PROGRESS',
              payload: false,
            },
          ],
          [],
        ));
    });

    describe('on failure', () => {
      beforeEach(() => {
        mock.onPost(state.exportEndpoint).replyOnce(HTTP_STATUS_NOT_FOUND);
      });

      it('does not dispatch downloadExport', () =>
        testAction(
          actions.fetchExport,
          undefined,
          state,
          [
            {
              type: 'SET_FETCHING_IN_PROGRESS',
              payload: true,
            },
            {
              type: 'SET_FETCHING_IN_PROGRESS',
              payload: false,
            },
          ],
          [],
        ).then(() => {
          expect(createAlert).toHaveBeenCalledTimes(1);
          expect(createAlert).toHaveBeenCalledWith({
            message: FETCH_EXPORT_ERROR_MESSAGE,
          });
        }));
    });
  });

  describe('downloadExport', () => {
    let mock;

    beforeEach(() => {
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('on success', () => {
      beforeEach(() => {
        mock
          .onGet(mockResponseExportEndpoint.self)
          .replyOnce(HTTP_STATUS_OK, mockResponseExportEndpoint);
      });

      describe.each`
        namespaceType             | fileName
        ${NAMESPACE_ORGANIZATION} | ${DEPENDENCIES_CSV_FILENAME}
        ${NAMESPACE_GROUP}        | ${DEPENDENCIES_FILENAME}
        ${NAMESPACE_PROJECT}      | ${DEPENDENCIES_FILENAME}
      `('$namespaceType', ({ namespaceType, fileName }) => {
        it(`saves the file as ${fileName}`, async () => {
          await testAction(
            actions.downloadExport,
            mockResponseExportEndpoint.self,
            { namespaceType },
            [
              {
                type: 'SET_FETCHING_IN_PROGRESS',
                payload: false,
              },
            ],
            [],
          );

          expect(download).toHaveBeenCalledTimes(1);
          expect(download).toHaveBeenCalledWith({
            url: mockResponseExportEndpoint.download,
            fileName,
          });
        });
      });
    });

    describe('on failure', () => {
      beforeEach(() => {
        mock.onGet(mockResponseExportEndpoint.self).replyOnce(HTTP_STATUS_NOT_FOUND);
      });

      it('sets SET_FETCHING_IN_PROGRESS', () =>
        testAction(
          actions.downloadExport,
          mockResponseExportEndpoint.self,
          undefined,
          [
            {
              type: 'SET_FETCHING_IN_PROGRESS',
              payload: false,
            },
          ],
          [],
        ).then(() => {
          expect(createAlert).toHaveBeenCalledTimes(1);
          expect(createAlert).toHaveBeenCalledWith({
            message: FETCH_EXPORT_ERROR_MESSAGE,
          });
          expect(download).toHaveBeenCalledTimes(0);
        }));
    });
  });

  describe('setSortField', () => {
    it('commits the SET_SORT_FIELD mutation and dispatch the fetchDependencies action', () => {
      const field = 'packager';

      return testAction(
        actions.setSortField,
        field,
        getInitialState(),
        [
          {
            type: types.SET_SORT_FIELD,
            payload: field,
          },
        ],
        [
          {
            type: 'fetchDependencies',
            payload: { page: 1 },
          },
        ],
      );
    });
  });

  describe('toggleSortOrder', () => {
    it('commits the TOGGLE_SORT_ORDER mutation and dispatch the fetchDependencies action', () =>
      testAction(
        actions.toggleSortOrder,
        undefined,
        getInitialState(),
        [
          {
            type: types.TOGGLE_SORT_ORDER,
          },
        ],
        [
          {
            type: 'fetchDependencies',
            payload: { page: 1 },
          },
        ],
      ));
  });

  describe('setSearchFilterParameters', () => {
    it('takes an array of filter objects, generates a fetch-parameter object and commits it to SET_SEARCH_FILTER_PARAMETERS', () => {
      const filters = [
        {
          type: 'packager',
          value: { data: ['bundler'] },
        },
        {
          type: 'project',
          value: { data: ['GitLab', 'Gnome'] },
        },
        // filters that contain strings (this happens when a user types in a value) should be ignored
        {
          type: 'ignored',
          value: { data: 'string_value' },
        },
      ];

      const expected = {
        project: ['GitLab', 'Gnome'],
        packager: ['bundler'],
      };

      return testAction(
        actions.setSearchFilterParameters,
        filters,
        getInitialState(),
        [
          {
            type: types.SET_SEARCH_FILTER_PARAMETERS,
            payload: expected,
          },
        ],
        [],
      );
    });

    describe('with a license filter', () => {
      it('maps the given license names to their corresponding SPDX identifiers', () => {
        const initialStateWithLicenses = {
          ...getInitialState(),
          licenses: [
            { name: 'BSD Zero Clause License', spdxIdentifier: '0BSD' },
            { name: 'Apache 2.0', spdxIdentifier: 'Apache-2.0' },
          ],
        };

        const filters = [
          {
            type: 'licenses',
            value: { data: ['BSD Zero Clause License', 'Apache 2.0'] },
          },
        ];

        const expected = {
          licenses: ['0BSD', 'Apache-2.0'],
        };

        return testAction(
          actions.setSearchFilterParameters,
          filters,
          initialStateWithLicenses,
          [
            {
              type: types.SET_SEARCH_FILTER_PARAMETERS,
              payload: expected,
            },
          ],
          [],
        );
      });
    });
  });

  describe('fetchLicenses', () => {
    let mock;
    const licensesEndpoint = `${TEST_HOST}/licenses`;

    beforeEach(() => {
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('when the given endpoint is empty', () => {
      it('does nothing', () => {
        testAction(actions.fetchLicenses, undefined, getInitialState(), [], []);
      });
    });

    describe('on success', () => {
      it('correctly sets the loading state and the fetched licenses transformed to camelCased and an added id property', () => {
        const licenses = [
          {
            name: 'BSD Zero Clause License',
            spdx_Identifier: '0BSD',
            web_url: 'https://spdx.org/licenses/0BSD.html',
          },
        ];
        const camelCasedLicensesWithId = [
          {
            id: 0,
            name: 'BSD Zero Clause License',
            spdxIdentifier: '0BSD',
            webUrl: 'https://spdx.org/licenses/0BSD.html',
          },
        ];

        mock.onGet(licensesEndpoint).replyOnce(HTTP_STATUS_OK, { licenses });

        testAction(
          actions.fetchLicenses,
          licensesEndpoint,
          getInitialState(),
          [
            {
              type: types.SET_FETCHING_LICENSES_IN_PROGRESS,
              payload: true,
            },
            {
              type: types.SET_LICENSES,
              payload: camelCasedLicensesWithId,
            },
            {
              type: types.SET_FETCHING_LICENSES_IN_PROGRESS,
              payload: false,
            },
          ],
          [],
        );
      });
    });

    describe('on error', () => {
      it('creates an alert and sets the loading state to be "false"', async () => {
        mock.onGet(licensesEndpoint).replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);

        await testAction(
          actions.fetchLicenses,
          licensesEndpoint,
          getInitialState(),
          [
            {
              type: types.SET_FETCHING_LICENSES_IN_PROGRESS,
              payload: true,
            },
            {
              type: types.SET_FETCHING_LICENSES_IN_PROGRESS,
              payload: false,
            },
          ],
          [],
        );

        expect(createAlert).toHaveBeenCalledTimes(1);
        expect(createAlert).toHaveBeenCalledWith({
          message: LICENSES_FETCH_ERROR_MESSAGE,
        });
      });
    });
  });

  describe('fetchVulnerabilities', () => {
    let mock;
    const dependenciesEndpoint = `${TEST_HOST}/vulnerabilities`;
    const item = { occurrenceId: 1 };

    beforeEach(() => {
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('when the given endpoint is empty', () => {
      it('does nothing', () => {
        testAction(
          actions.fetchVulnerabilities,
          { item: null, vulnerabilitiesEndpoint: null },
          getInitialState(),
          [],
          [],
        );
      });
    });

    describe('on success', () => {
      const payload = [{ occurrence_id: 1 }];

      it('correctly sets the loading item and the fetched vulnerabilities', async () => {
        mock.onGet(dependenciesEndpoint).replyOnce(HTTP_STATUS_OK, payload);

        await testAction(
          actions.fetchVulnerabilities,
          { item, vulnerabilitiesEndpoint: dependenciesEndpoint },
          getInitialState(),
          [
            {
              type: types.TOGGLE_VULNERABILITY_ITEM_LOADING,
              payload: item,
            },
            {
              type: types.SET_VULNERABILITIES,
              payload,
            },
            {
              type: types.TOGGLE_VULNERABILITY_ITEM_LOADING,
              payload: item,
            },
          ],
          [],
        );
      });
    });

    describe('on error', () => {
      it('creates an alert and sets vulnerability item to null', async () => {
        mock.onGet(dependenciesEndpoint).replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);

        await testAction(
          actions.fetchVulnerabilities,
          { item, vulnerabilitiesEndpoint: dependenciesEndpoint },
          getInitialState(),
          [
            {
              type: types.TOGGLE_VULNERABILITY_ITEM_LOADING,
              payload: item,
            },
            {
              type: types.TOGGLE_VULNERABILITY_ITEM_LOADING,
              payload: item,
            },
          ],
          [],
        );

        expect(createAlert).toHaveBeenCalledTimes(1);
        expect(createAlert).toHaveBeenCalledWith({
          message: VULNERABILITIES_FETCH_ERROR_MESSAGE,
        });
      });
    });
  });
});
