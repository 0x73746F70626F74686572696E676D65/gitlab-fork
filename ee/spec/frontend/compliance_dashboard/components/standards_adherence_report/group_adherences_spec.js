import { shallowMount } from '@vue/test-utils';
import { GlAccordion, GlAccordionItem } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import AdherenceBaseTable from 'ee/compliance_dashboard/components/standards_adherence_report/base_table.vue';
import GroupAdherences from 'ee/compliance_dashboard/components/standards_adherence_report/group_adherences.vue';
import { ROUTE_STANDARDS_ADHERENCE } from 'ee/compliance_dashboard/constants';

describe('GroupAdherences component', () => {
  let wrapper;
  let $router;
  const groupPath = 'example-group-path';

  const findCheckGroupHeaders = () => wrapper.findAllByTestId('grouped-check');
  const findProjectGroupHeaders = () => wrapper.findAllByTestId('grouped-project');
  const findStandardGroupHeaders = () => wrapper.findAllByTestId('grouped-standard');

  function createComponent(props = {}, queryParams = {}) {
    const currentQueryParams = { ...queryParams };
    $router = {
      push: jest.fn().mockImplementation(({ query }) => {
        Object.assign(currentQueryParams, query);
      }),
    };

    wrapper = extendedWrapper(
      shallowMount(GroupAdherences, {
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
        stubs: {
          GlAccordion,
          GlAccordionItem,
          AdherenceBaseTable,
        },
      }),
    );
  }

  describe('grouping by checks', () => {
    beforeEach(() => {
      createComponent({ selected: 'Checks' });
    });

    it('lists all checks', () => {
      expect(findCheckGroupHeaders().length).toBe(4);
      expect(findCheckGroupHeaders().at(0).text()).toMatch('Prevent authors as approvers');
      expect(findCheckGroupHeaders().at(1).text()).toMatch('Prevent committers as approvers');
      expect(findCheckGroupHeaders().at(2).text()).toMatch('At least two approvals');
      expect(findCheckGroupHeaders().at(3).text()).toMatch('At least one non-author approval');
    });

    it('contains correct `check` prop to AdherenceBaseTable component', () => {
      expect(findCheckGroupHeaders().at(0).findComponent(AdherenceBaseTable).props()).toMatchObject(
        {
          groupPath: 'example-group-path',
          filters: {},
          check: 'PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR',
        },
      );

      expect(findCheckGroupHeaders().at(1).findComponent(AdherenceBaseTable).props()).toMatchObject(
        {
          groupPath: 'example-group-path',
          filters: {},
          check: 'PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS',
        },
      );

      expect(findCheckGroupHeaders().at(2).findComponent(AdherenceBaseTable).props()).toMatchObject(
        {
          groupPath: 'example-group-path',
          filters: {},
          check: 'AT_LEAST_TWO_APPROVALS',
        },
      );

      expect(findCheckGroupHeaders().at(3).findComponent(AdherenceBaseTable).props()).toMatchObject(
        {
          groupPath: 'example-group-path',
          filters: {},
          check: 'AT_LEAST_ONE_NON_AUTHOR_APPROVAL',
        },
      );
    });
  });

  describe('grouping by projects', () => {
    beforeEach(() => {
      createComponent({
        selected: 'Projects',
        projects: [
          { name: 'Project A', id: 'project-a' },
          { name: 'Project B', id: 'project-b' },
          { name: 'Project C', id: 'project-c' },
        ],
      });
    });

    it('lists all projects', () => {
      expect(findProjectGroupHeaders().length).toBe(3);
      expect(findProjectGroupHeaders().at(0).text()).toMatch('Project A');
      expect(findProjectGroupHeaders().at(1).text()).toMatch('Project B');
      expect(findProjectGroupHeaders().at(2).text()).toMatch('Project C');
    });

    it('contains correct `projectId` prop to AdherenceBaseTable component', () => {
      expect(
        findProjectGroupHeaders().at(0).findComponent(AdherenceBaseTable).props(),
      ).toMatchObject({
        groupPath: 'example-group-path',
        filters: {},
        projectId: 'project-a',
      });

      expect(
        findProjectGroupHeaders().at(1).findComponent(AdherenceBaseTable).props(),
      ).toMatchObject({
        groupPath: 'example-group-path',
        filters: {},
        projectId: 'project-b',
      });

      expect(
        findProjectGroupHeaders().at(2).findComponent(AdherenceBaseTable).props(),
      ).toMatchObject({
        groupPath: 'example-group-path',
        filters: {},
        projectId: 'project-c',
      });
    });
  });

  describe('grouping by standards', () => {
    beforeEach(() => {
      createComponent({ selected: 'Standards' });
    });

    it('lists all standards', () => {
      expect(findStandardGroupHeaders().length).toBe(2);
      expect(findStandardGroupHeaders().at(0).text()).toMatch('GitLab');
      expect(findStandardGroupHeaders().at(1).text()).toMatch('SOC 2');
    });

    it('contains correct `check` prop to AdherenceBaseTable component', () => {
      expect(
        findStandardGroupHeaders().at(0).findComponent(AdherenceBaseTable).props(),
      ).toMatchObject({
        groupPath: 'example-group-path',
        filters: {},
        standard: 'GITLAB',
      });
    });
  });
});
