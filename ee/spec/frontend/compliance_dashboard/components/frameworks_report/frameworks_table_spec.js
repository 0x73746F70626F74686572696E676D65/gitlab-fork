import { GlLoadingIcon, GlSearchBoxByClick, GlTable, GlLink, GlModal } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';

import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';

import { createComplianceFrameworksReportResponse } from 'ee_jest/compliance_dashboard/mock_data';
import FrameworksTable from 'ee/compliance_dashboard/components/frameworks_report/frameworks_table.vue';
import FrameworkInfoDrawer from 'ee/compliance_dashboard/components/frameworks_report/framework_info_drawer.vue';
import { ROUTE_EDIT_FRAMEWORK, ROUTE_NEW_FRAMEWORK } from 'ee/compliance_dashboard/constants';

Vue.use(VueApollo);

describe('FrameworksTable component', () => {
  let wrapper;

  const frameworksResponse = createComplianceFrameworksReportResponse({ count: 2, projects: 2 });
  const frameworks = frameworksResponse.data.namespace.complianceFrameworks.nodes;
  const projects = frameworks[0].projects.nodes;
  const rowCheckIndex = 0;
  const GlModalStub = stubComponent(GlModal, { methods: { show: jest.fn(), hide: jest.fn() } });

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableHeaders = () => findTable().findAll('th > div > span');
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findEmptyState = () => wrapper.findByText('No frameworks found');
  const findTableLinks = (idx) => findTableRow(idx).findAllComponents(GlLink);
  const findFrameworkInfoSidebar = () => wrapper.findComponent(FrameworkInfoDrawer);
  const findNewFrameworkButton = () => wrapper.findByText('New framework');
  const findSearchBox = () => wrapper.findComponent(GlSearchBoxByClick);

  const openSidebar = async () => {
    findTableRow(rowCheckIndex).trigger('click');
    await nextTick();
  };

  let routerPushMock;
  const createComponent = (props = {}) => {
    routerPushMock = jest.fn();
    return mountExtended(FrameworksTable, {
      propsData: {
        groupPath: 'foo',
        frameworks: [],
        isLoading: true,
        ...props,
      },
      provide: {
        groupSecurityPoliciesPath: '/example-group-security-policies-path',
      },
      mocks: {
        $router: { push: routerPushMock },
      },
      stubs: {
        EditForm: true,
        GlModal: GlModalStub,
      },
      attachTo: document.body,
    });
  };

  describe('default behavior', () => {
    it('renders the loading indicator while loading', () => {
      wrapper = createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findTable().text()).not.toContain('No frameworks found');
    });

    it('renders the empty state when no frameworks found', () => {
      wrapper = createComponent({ isLoading: false });

      const emptyState = findEmptyState();

      expect(findLoadingIcon().exists()).toBe(false);
      expect(emptyState.exists()).toBe(true);
      expect(emptyState.text()).toBe('No frameworks found');
    });

    it('has the correct table headers', () => {
      wrapper = createComponent({ isLoading: false });
      const headerTexts = findTableHeaders().wrappers.map((h) => h.text());

      expect(headerTexts).toStrictEqual(['Frameworks', 'Associated projects', 'Policies']);
    });

    it('navigates to add framework page when requested', () => {
      wrapper = createComponent({ isLoading: false });
      const newFrameworkButton = findNewFrameworkButton();

      newFrameworkButton.trigger('click');
      expect(routerPushMock).toHaveBeenCalledWith({ name: ROUTE_NEW_FRAMEWORK });
    });

    it('emits search event when underlying search box is submitted', () => {
      wrapper = createComponent({ isLoading: false });

      findSearchBox().vm.$emit('submit', 'test');
      expect(wrapper.emitted('search').at(-1)).toStrictEqual(['test']);
    });

    it('emits search event with empty value when underlying search box is cleared', () => {
      wrapper = createComponent({ isLoading: false });

      findSearchBox().vm.$emit('clear');
      expect(wrapper.emitted('search').at(-1)).toStrictEqual(['']);
    });
  });

  describe('when there are policies', () => {
    beforeEach(() => {
      wrapper = createComponent({
        frameworks,
        isLoading: false,
      });
    });

    it.each(Object.keys(frameworks))('has the correct data for row %s', (idx) => {
      const frameworkPolicies = findTableRowData(idx)
        .wrappers.map((d) => d.text())
        .at(2);
      expect(frameworkPolicies).toMatch(
        [
          ...frameworks[idx].scanExecutionPolicies.nodes,
          ...frameworks[idx].scanResultPolicies.nodes,
        ]
          .map((x) => x.name)
          .join(','),
      );
    });
  });

  describe('when there are projects', () => {
    beforeEach(() => {
      wrapper = createComponent({
        frameworks,
        isLoading: false,
      });
    });

    it.each(Object.keys(frameworks))('has the correct data for row %s', (idx) => {
      const [frameworkName, associatedProjects] = findTableRowData(idx).wrappers.map((d) =>
        d.text(),
      );
      expect(frameworkName).toContain(frameworks[idx].name);
      expect(associatedProjects).toContain(projects[idx].name);
      expect(findTableLinks(idx).wrappers).toHaveLength(2);
      expect(findTableLinks(idx).wrappers.map((w) => w.attributes('href'))).toStrictEqual(
        projects.map((p) => p.webUrl),
      );
    });

    describe('Sidebar', () => {
      describe('closing the sidebar', () => {
        it('has the correct props when closed', async () => {
          await openSidebar();

          await findFrameworkInfoSidebar().vm.$emit('close');

          expect(findFrameworkInfoSidebar().props('framework')).toBe(null);
        });
      });

      describe('edit button in sidebar', () => {
        it('opens edit form for the framework', async () => {
          await openSidebar();

          await findFrameworkInfoSidebar().vm.$emit('edit', frameworks[rowCheckIndex]);

          expect(routerPushMock).toHaveBeenCalledWith({
            name: ROUTE_EDIT_FRAMEWORK,
            params: { id: frameworks[rowCheckIndex].id },
          });
        });
      });

      describe('opening the sidebar', () => {
        it('has the correct props when opened', async () => {
          await openSidebar();

          expect(findFrameworkInfoSidebar().props('framework')).toMatchObject(
            frameworks[rowCheckIndex],
          );
        });
      });
    });
  });
});
