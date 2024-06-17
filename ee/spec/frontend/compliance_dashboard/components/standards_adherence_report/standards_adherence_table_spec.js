import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { mount } from '@vue/test-utils';
import { GlDisclosureDropdown } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { ROUTE_STANDARDS_ADHERENCE } from 'ee/compliance_dashboard/constants';
import ComplianceStandardsAdherenceTable from 'ee/compliance_dashboard/components/standards_adherence_report/standards_adherence_table.vue';
import Filters from 'ee/compliance_dashboard/components/standards_adherence_report/filters.vue';
import getProjectComplianceStandardsAdherence from 'ee/compliance_dashboard/graphql/compliance_standards_adherence.query.graphql';
import getProjectsInComplianceStandardsAdherence from 'ee/compliance_dashboard/graphql/compliance_projects_in_standards_adherence.query.graphql';
import { mapStandardsAdherenceQueryToFilters } from 'ee/compliance_dashboard/utils';
import { createComplianceAdherencesResponse } from '../../mock_data';

Vue.use(VueApollo);

describe('ComplianceStandardsAdherenceTable component', () => {
  let wrapper;
  let $router;
  let apolloProvider;
  const groupPath = 'example-group-path';

  const defaultAdherencesResponse = createComplianceAdherencesResponse({ count: 2 });
  const mockGraphQlSuccess = jest.fn().mockResolvedValue(defaultAdherencesResponse);
  const mockGraphQlLoading = jest.fn().mockResolvedValue(new Promise(() => {}));
  const createMockApolloProvider = (resolverMock) => {
    return createMockApollo([
      [getProjectComplianceStandardsAdherence, resolverMock],
      [getProjectsInComplianceStandardsAdherence, mockGraphQlLoading],
    ]);
  };

  const findFilters = () => wrapper.findComponent(Filters);
  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);

  function createComponent(props = {}, resolverMock = mockGraphQlLoading, queryParams = {}) {
    const currentQueryParams = { ...queryParams };
    $router = {
      push: jest.fn().mockImplementation(({ query }) => {
        Object.assign(currentQueryParams, query);
      }),
    };

    apolloProvider = createMockApolloProvider(resolverMock);

    wrapper = extendedWrapper(
      mount(ComplianceStandardsAdherenceTable, {
        apolloProvider,
        data() {
          return {
            projects: {
              list: [{ name: 'Project 1', id: 'gid://gitlab/Project/1' }],
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

  beforeEach(() => {
    createComponent({}, mockGraphQlSuccess);

    return waitForPromises();
  });

  describe('filtering', () => {
    describe('by standard', () => {
      it('fetches the filtered adherences', async () => {
        findFilters().vm.$emit('submit', [{ type: 'standard', value: { data: 'GITLAB' } }]);
        await waitForPromises();

        expect(mockGraphQlSuccess).toHaveBeenCalledTimes(2);
        expect(mockGraphQlSuccess).toHaveBeenNthCalledWith(2, {
          after: undefined,
          fullPath: groupPath,
          filters: mapStandardsAdherenceQueryToFilters([
            { type: 'standard', value: { data: 'GITLAB' } },
          ]),
          first: 20,
        });
      });
    });

    describe('by project', () => {
      it('fetches the filtered adherences', async () => {
        findFilters().vm.$emit('submit', [
          { type: 'project', value: { data: 'gid://gitlab/Project/1' } },
        ]);
        await waitForPromises();

        expect(mockGraphQlSuccess).toHaveBeenCalledTimes(2);
        expect(mockGraphQlSuccess).toHaveBeenNthCalledWith(2, {
          after: undefined,
          fullPath: groupPath,
          filters: mapStandardsAdherenceQueryToFilters([
            { type: 'project', value: { data: 'gid://gitlab/Project/1' } },
          ]),
          first: 20,
        });
      });
    });

    describe('by check name', () => {
      it('fetches the filtered adherences', async () => {
        findFilters().vm.$emit('submit', [
          { type: 'check', value: { data: 'AT_LEAST_TWO_APPROVALS' } },
        ]);
        await waitForPromises();

        expect(mockGraphQlSuccess).toHaveBeenCalledTimes(2);
        expect(mockGraphQlSuccess).toHaveBeenNthCalledWith(2, {
          after: undefined,
          fullPath: groupPath,
          filters: mapStandardsAdherenceQueryToFilters([
            { type: 'check', value: { data: 'AT_LEAST_TWO_APPROVALS' } },
          ]),
          first: 20,
        });
      });
    });
  });

  describe('grouping', () => {
    it('contains the correct dropdown options when no global project id provided', () => {
      expect(findDropdown().props('items')).toEqual([
        { text: 'None' },
        { text: 'Checks' },
        { text: 'Projects' },
        { text: 'Standards' },
      ]);
    });

    it('contains the correct dropdown options when global project id provided', () => {
      createComponent({ globalProjectId: 26 }, mockGraphQlSuccess);
      expect(findDropdown().props('items')).toEqual([
        { text: 'None' },
        { text: 'Checks' },
        { text: 'Standards' },
      ]);
    });

    it('resets pagination', async () => {
      findDropdown().vm.$emit('action', { text: 'Checks' });
      await nextTick();

      expect($router.push).toHaveBeenCalledWith(
        expect.objectContaining({
          query: {
            after: undefined,
            before: undefined,
          },
        }),
      );
    });

    describe('by none', () => {
      it('fetches the non grouped adherences', () => {
        expect(findDropdown().props('toggleText')).toBe('None');
        expect(mockGraphQlSuccess).toHaveBeenCalledTimes(1);
      });
    });

    describe('by checks', () => {
      it('fetches the grouped adherences', async () => {
        findDropdown().vm.$emit('action', { text: 'Checks' });
        await nextTick();

        expect(findDropdown().props('toggleText')).toBe('Checks');
        expect(mockGraphQlSuccess).toHaveBeenCalledTimes(5);
      });
    });

    describe('by projects', () => {
      it('fetches the grouped adherences', async () => {
        findDropdown().vm.$emit('action', { text: 'Projects' });
        await nextTick();

        expect(findDropdown().props('toggleText')).toBe('Projects');
        expect(mockGraphQlSuccess).toHaveBeenCalledTimes(2);
      });
    });

    describe('by standards', () => {
      it('fetches the grouped adherences', async () => {
        findDropdown().vm.$emit('action', { text: 'Standards' });
        await nextTick();

        expect(findDropdown().props('toggleText')).toBe('Standards');
        expect(mockGraphQlSuccess).toHaveBeenCalledTimes(3);
      });
    });
  });
});
