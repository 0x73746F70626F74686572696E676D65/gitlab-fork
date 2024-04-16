import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { mount, shallowMount } from '@vue/test-utils';
import { GlAlert, GlLink, GlTable, GlLoadingIcon } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import getProjectComplianceStandardsAdherence from 'ee/compliance_dashboard/graphql/compliance_standards_adherence.query.graphql';
import getProjectsInComplianceStandardsAdherence from 'ee/compliance_dashboard/graphql/compliance_projects_in_standards_adherence.query.graphql';
import AdherenceBaseTable from 'ee/compliance_dashboard/components/standards_adherence_report/base_table.vue';
import FixSuggestionsSidebar from 'ee/compliance_dashboard/components/standards_adherence_report/fix_suggestions_sidebar.vue';
import Pagination from 'ee/compliance_dashboard/components/shared/pagination.vue';
import { ROUTE_STANDARDS_ADHERENCE } from 'ee/compliance_dashboard/constants';
import { createComplianceAdherencesResponse } from 'ee_jest/compliance_dashboard/mock_data';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

describe('AdherencesBaseTable component', () => {
  let wrapper;
  let $router;
  let apolloProvider;

  const groupPath = 'example-group-path';
  const sentryError = new Error('GraphQL networkError');

  const defaultAdherencesResponse = createComplianceAdherencesResponse({ count: 2 });
  const mockGraphQlLoading = jest.fn().mockResolvedValue(new Promise(() => {}));
  const mockGraphQlSuccess = jest.fn().mockResolvedValue(defaultAdherencesResponse);
  const mockGraphQlError = jest.fn().mockRejectedValue(sentryError);
  const createMockApolloProvider = (resolverMock) => {
    return createMockApollo([
      [getProjectComplianceStandardsAdherence, resolverMock],
      [getProjectsInComplianceStandardsAdherence, mockGraphQlLoading],
    ]);
  };

  const findAdherencesBaseTable = () => wrapper.findComponent(GlTable);
  const findErrorMessage = () => wrapper.findComponent(GlAlert);
  const findFixSuggestionSidebar = () => wrapper.findComponent(FixSuggestionsSidebar);
  const findTableHeaders = () => findAdherencesBaseTable().findAll('th');
  const findTableLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findTableRows = () => findAdherencesBaseTable().findAll('tr');
  const findNthTableRow = (n) => findTableRows().at(n);
  const findFirstTableRowData = () => findNthTableRow(1).findAll('td');
  const findViewDetails = () => wrapper.findComponent(GlLink);
  const findPagination = () => wrapper.findComponent(Pagination);

  function createComponent(
    mountFn = shallowMount,
    props = {},
    resolverMock = mockGraphQlLoading,
    queryParams = {},
  ) {
    const currentQueryParams = { ...queryParams };
    $router = {
      push: jest.fn().mockImplementation(({ query }) => {
        Object.assign(currentQueryParams, query);
      }),
    };

    apolloProvider = createMockApolloProvider(resolverMock);

    wrapper = extendedWrapper(
      mountFn(AdherenceBaseTable, {
        apolloProvider,
        data() {
          return {
            projects: {
              list: [{ id: 'gid://gitlab/Project/1' }],
            },
          };
        },
        propsData: {
          groupPath,
          ...props,
        },
        mocks: {
          $router,
          $route: {
            name: ROUTE_STANDARDS_ADHERENCE,
            query: currentQueryParams,
          },
        },
      }),
    );
  }

  const openSidebar = async () => {
    await findViewDetails().trigger('click');
    await nextTick();
  };

  describe('default behavior', () => {
    beforeEach(() => {
      createComponent(mount);
    });

    it('does not render an error message', () => {
      expect(findErrorMessage().exists()).toBe(false);
    });

    it('has the correct table headers', () => {
      const headerTexts = findTableHeaders().wrappers.map((h) => h.text());

      expect(headerTexts).toStrictEqual([
        'Status',
        'Project',
        'Check',
        'Standard',
        'Date since last status change',
        'More information',
      ]);
    });
  });

  describe('when the adherence query fails', () => {
    beforeEach(() => {
      jest.spyOn(Sentry, 'captureException');
      createComponent(shallowMount, {}, mockGraphQlError);
    });

    it('renders the error message', async () => {
      await waitForPromises();

      expect(findErrorMessage().text()).toBe(
        'Unable to load the standards adherence report. Refresh the page and try again.',
      );
      expect(Sentry.captureException.mock.calls[0][0].networkError).toBe(sentryError);
    });
  });

  describe('when there are no standards adherence checks available', () => {
    beforeEach(() => {
      const noAdherencesResponse = createComplianceAdherencesResponse({ count: 0 });
      const mockResolver = jest.fn().mockResolvedValue(noAdherencesResponse);

      createComponent(mount, {}, mockResolver);

      return waitForPromises();
    });

    it('renders the empty table message', () => {
      expect(findAdherencesBaseTable().text()).toContain(
        AdherenceBaseTable.noStandardsAdherencesFound,
      );
    });
  });

  describe('when there are standards adherence checks available', () => {
    beforeEach(() => {
      createComponent(mount, {}, mockGraphQlSuccess);

      return waitForPromises();
    });

    it('does not render the table loading icon', () => {
      expect(mockGraphQlSuccess).toHaveBeenCalledTimes(1);

      expect(findTableLoadingIcon().exists()).toBe(false);
    });

    it('renders the table row properly for failed checks', () => {
      const infoCell = findNthTableRow(2).findAll('td').at(-1);
      expect(infoCell.text()).toMatchInterpolatedText('View details (fix available)');
    });

    describe('when check is `PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR`', () => {
      it('renders the table row properly', () => {
        const [
          rowStatus,
          rowProject,
          rowCheck,
          rowStandard,
          rowDate,
        ] = findFirstTableRowData().wrappers.map((e) => e.text());

        expect(rowStatus).toContain('Success');
        expect(rowProject).toContain('Example Project');
        expect(rowCheck).toContain('Prevent authors as approvers');
        expect(rowStandard).toContain('GitLab');
        expect(rowDate).toContain('Jul 1, 2023');
      });
    });

    describe('when check is `PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS`', () => {
      beforeEach(() => {
        const preventApprovalbyMRCommitersAdherencesResponse = createComplianceAdherencesResponse({
          checkName: 'PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS',
        });
        const mockResolver = jest
          .fn()
          .mockResolvedValue(preventApprovalbyMRCommitersAdherencesResponse);

        createComponent(mount, {}, mockResolver);

        return waitForPromises();
      });

      it('renders the table row properly', () => {
        const [
          rowStatus,
          rowProject,
          rowCheck,
          rowStandard,
          rowDate,
        ] = findFirstTableRowData().wrappers.map((e) => e.text());

        expect(rowStatus).toContain('Success');
        expect(rowProject).toContain('Example Project');
        expect(rowCheck).toContain('Prevent committers as approvers');
        expect(rowStandard).toContain('GitLab');
        expect(rowDate).toContain('Jul 1, 2023');
      });
    });

    describe('when check is `AT_LEAST_TWO_APPROVALS`', () => {
      beforeEach(() => {
        const atLeastTwoApprovalsAdherencesResponse = createComplianceAdherencesResponse({
          checkName: 'AT_LEAST_TWO_APPROVALS',
        });
        const mockResolver = jest.fn().mockResolvedValue(atLeastTwoApprovalsAdherencesResponse);

        createComponent(mount, {}, mockResolver);

        return waitForPromises();
      });

      it('renders the table row properly', () => {
        const [
          rowStatus,
          rowProject,
          rowCheck,
          rowStandard,
          rowDate,
        ] = findFirstTableRowData().wrappers.map((e) => e.text());

        expect(rowStatus).toContain('Success');
        expect(rowProject).toContain('Example Project');
        expect(rowCheck).toContain('At least two approvals');
        expect(rowStandard).toContain('GitLab');
        expect(rowDate).toContain('Jul 1, 2023');
      });
    });

    describe('pagination', () => {
      describe('when there is more than one page of standards adherence checks available', () => {
        it('shows the pagination button', () => {
          expect(findPagination().exists()).toBe(true);
        });

        describe('when a different size is selected', () => {
          it('resets to the first page and updates the page size', async () => {
            findPagination().vm.$emit('page-size-change', 50);
            await waitForPromises();

            expect($router.push).toHaveBeenCalledWith(
              expect.objectContaining({
                query: {
                  perPage: 50,
                },
              }),
            );
          });
        });

        describe('when the next page has been selected', () => {
          it('updates and calls the graphql query', async () => {
            findPagination().vm.$emit('next', 'next-value');
            await waitForPromises();

            expect($router.push).toHaveBeenCalledWith(
              expect.objectContaining({
                query: {
                  after: 'next-value',
                  before: undefined,
                },
              }),
            );
          });
        });

        describe('when the prev page has been selected', () => {
          it('updates and calls the graphql query', async () => {
            findPagination().vm.$emit('prev', 'prev-value');
            await waitForPromises();

            expect($router.push).toHaveBeenCalledWith(
              expect.objectContaining({
                query: {
                  after: undefined,
                  before: 'prev-value',
                },
              }),
            );
          });
        });
      });

      describe('when there is only one page of standards adherence checks available', () => {
        beforeEach(() => {
          const response = createComplianceAdherencesResponse({
            pageInfo: {
              hasNextPage: false,
              hasPreviousPage: false,
            },
          });
          const mockResolver = jest.fn().mockResolvedValue(response);

          createComponent(mount, {}, mockResolver);
          return waitForPromises();
        });

        it('does not show the pagination', () => {
          expect(findPagination().exists()).toBe(false);
        });
      });
    });
  });

  describe('fixSuggestionSidebar', () => {
    beforeEach(() => {
      createComponent(mount, {}, mockGraphQlSuccess);

      return waitForPromises();
    });

    describe('closing the sidebar', () => {
      it('has the correct props when closed', async () => {
        await openSidebar();

        await findFixSuggestionSidebar().vm.$emit('close');

        expect(findFixSuggestionSidebar().props('groupPath')).toBe('example-group-path');
        expect(findFixSuggestionSidebar().props('showDrawer')).toBe(false);
        expect(findFixSuggestionSidebar().props('adherence')).toStrictEqual({});
      });
    });

    describe('opening the sidebar', () => {
      it('has the correct props when opened', async () => {
        await openSidebar();

        expect(findFixSuggestionSidebar().props('groupPath')).toBe('example-group-path');
        expect(findFixSuggestionSidebar().props('showDrawer')).toBe(true);
        expect(findFixSuggestionSidebar().props('adherence')).toStrictEqual(
          wrapper.vm.adherences.list[0],
        );
      });
    });
  });
});
