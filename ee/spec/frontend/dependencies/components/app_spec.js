import { GlEmptyState, GlLoadingIcon, GlLink } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { s__ } from '~/locale';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import DependenciesApp from 'ee/dependencies/components/app.vue';
import DependenciesActions from 'ee/dependencies/components/dependencies_actions.vue';
import DependencyListIncompleteAlert from 'ee/dependencies/components/dependency_list_incomplete_alert.vue';
import DependencyListJobFailedAlert from 'ee/dependencies/components/dependency_list_job_failed_alert.vue';
import PaginatedDependenciesTable from 'ee/dependencies/components/paginated_dependencies_table.vue';
import createStore from 'ee/dependencies/store';
import { DEPENDENCY_LIST_TYPES } from 'ee/dependencies/store/constants';
import {
  NAMESPACE_GROUP,
  NAMESPACE_ORGANIZATION,
  NAMESPACE_PROJECT,
} from 'ee/dependencies/constants';
import { REPORT_STATUS } from 'ee/dependencies/store/modules/list/constants';
import { TEST_HOST } from 'helpers/test_constants';
import { getDateInPast } from '~/lib/utils/datetime_utility';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import axios from '~/lib/utils/axios_utils';

describe('DependenciesApp component', () => {
  let store;
  let wrapper;
  let mock;

  const { namespace: allNamespace } = DEPENDENCY_LIST_TYPES.all;

  const basicAppProps = {
    endpoint: '/foo',
    exportEndpoint: '/bar',
    emptyStateSvgPath: '/bar.svg',
    documentationPath: TEST_HOST,
    pageInfo: {},
    supportDocumentationPath: `${TEST_HOST}/dependency_scanning#supported-languages`,
    namespaceType: 'project',
    vulnerabilitiesEndpoint: `/vulnerabilities`,
  };

  const factory = ({ provide } = {}) => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();

    const stubs = Object.keys(DependenciesApp.components).filter((name) => name !== 'GlSprintf');

    wrapper = extendedWrapper(
      mount(DependenciesApp, {
        store,
        stubs,
        provide: { ...basicAppProps, ...provide },
      }),
    );
  };

  const setStateJobNotRun = () => {
    Object.assign(store.state[allNamespace], {
      initialized: true,
      isLoading: false,
      dependencies: [],
    });
    store.state[allNamespace].pageInfo.total = 0;
    store.state[allNamespace].reportInfo.status = REPORT_STATUS.jobNotSetUp;
  };

  const setStateLoaded = () => {
    const total = 2;
    Object.assign(store.state[allNamespace], {
      initialized: true,
      isLoading: false,
      dependencies: Array(total)
        .fill(null)
        .map((_, id) => ({ id })),
    });
    store.state[allNamespace].pageInfo.total = total;
    store.state[allNamespace].reportInfo.status = REPORT_STATUS.ok;
    store.state[allNamespace].reportInfo.generatedAt = getDateInPast(new Date(), 7);
    store.state[allNamespace].reportInfo.jobPath = '/jobs/foo/321';
  };

  const setStateJobFailed = () => {
    Object.assign(store.state[allNamespace], {
      initialized: true,
      isLoading: false,
      dependencies: [],
    });
    store.state[allNamespace].pageInfo.total = 0;
    store.state[allNamespace].reportInfo.status = REPORT_STATUS.jobFailed;
    store.state[allNamespace].reportInfo.jobPath = '/jobs/foo/321';
  };

  const setStateListIncomplete = () => {
    Object.assign(store.state[allNamespace], {
      initialized: true,
      isLoading: false,
      dependencies: [{ id: 0 }],
    });
    store.state[allNamespace].pageInfo.total = 1;
    store.state[allNamespace].reportInfo.status = REPORT_STATUS.incomplete;
  };

  const setStateNoDependencies = () => {
    Object.assign(store.state[allNamespace], {
      initialized: true,
      isLoading: false,
      dependencies: [],
    });
    store.state[allNamespace].pageInfo.total = 0;
    store.state[allNamespace].reportInfo.status = REPORT_STATUS.noDependencies;
  };

  const findJobFailedAlert = () => wrapper.findComponent(DependencyListJobFailedAlert);
  const findIncompleteListAlert = () => wrapper.findComponent(DependencyListIncompleteAlert);
  const findDependenciesTables = () => wrapper.findAllComponents(PaginatedDependenciesTable);

  const findHeader = () => wrapper.find('section > header');
  const findExportButton = () => wrapper.findByTestId('export');
  const findHeaderHelpLink = () => findHeader().findComponent(GlLink);
  const findHeaderJobLink = () => wrapper.findComponent({ ref: 'jobLink' });
  const findTimeAgoMessage = () => wrapper.findByTestId('time-ago-message');

  const expectComponentWithProps = (Component, props = {}) => {
    const componentWrapper = wrapper.findComponent(Component);
    expect(componentWrapper.isVisible()).toBe(true);
    expect(componentWrapper.props()).toEqual(expect.objectContaining(props));
  };

  const expectComponentPropsToMatchSnapshot = (Component) => {
    const componentWrapper = wrapper.findComponent(Component);
    expect(componentWrapper.props()).toMatchSnapshot();
  };

  const expectNoDependenciesTables = () => expect(findDependenciesTables()).toHaveLength(0);
  const expectNoHeader = () => expect(findHeader().exists()).toBe(false);

  const expectEmptyStateDescription = () => {
    expect(wrapper.html()).toContain(
      'The dependency list details information about the components used within your project.',
    );
  };

  const expectEmptyStateLink = () => {
    const emptyStateLink = wrapper.findComponent(GlLink);
    expect(emptyStateLink.html()).toContain('More Information');
    expect(emptyStateLink.attributes('href')).toBe(TEST_HOST);
    expect(emptyStateLink.attributes('target')).toBe('_blank');
  };

  const expectDependenciesTable = () => {
    const tables = findDependenciesTables();
    expect(tables).toHaveLength(1);
    expect(tables.at(0).props()).toEqual({ namespace: allNamespace });
  };

  const expectHeader = () => {
    expect(findHeader().exists()).toBe(true);
  };

  describe('on creation', () => {
    beforeEach(() => {
      mock = new MockAdapter(axios);
      factory();
    });

    afterEach(() => {
      mock.restore();
    });

    it('dispatches the correct initial actions', () => {
      expect(store.dispatch.mock.calls).toEqual([
        ['setDependenciesEndpoint', basicAppProps.endpoint],
        ['setExportDependenciesEndpoint', basicAppProps.exportEndpoint],
        ['setNamespaceType', basicAppProps.namespaceType],
        ['setPageInfo', expect.anything()],
        ['setSortField', 'severity'],
      ]);
    });

    describe('without export endpoint', () => {
      beforeEach(async () => {
        factory({ provide: { exportEndpoint: null } });
        setStateLoaded();

        await nextTick();
      });

      it('removes the export button', () => {
        expect(findExportButton().exists()).toBe(false);
      });
    });

    describe('with namespaceType set to organization', () => {
      beforeEach(async () => {
        factory({
          provide: { namespaceType: NAMESPACE_ORGANIZATION },
        });
        setStateLoaded();
        await nextTick();
      });

      it('removes the actions bar', () => {
        expect(wrapper.findComponent(DependenciesActions).exists()).toBe(false);
      });
    });

    describe('with namespaceType set to group', () => {
      beforeEach(() => {
        factory({ provide: { namespaceType: 'group' } });
      });

      it('dispatches setSortField with severity', () => {
        expect(store.dispatch.mock.calls).toEqual(
          expect.arrayContaining([['setSortField', 'severity']]),
        );
      });
    });

    it('shows only the loading icon', () => {
      expectComponentWithProps(GlLoadingIcon);
      expectNoHeader();
      expectNoDependenciesTables();
    });

    describe('given the dependency list job has not yet run', () => {
      beforeEach(async () => {
        setStateJobNotRun();

        await nextTick();
      });

      it('shows only the empty state', () => {
        expectComponentWithProps(GlEmptyState, { svgPath: basicAppProps.emptyStateSvgPath });
        expectComponentPropsToMatchSnapshot(GlEmptyState);
        expectEmptyStateDescription();
        expectEmptyStateLink();
        expectNoHeader();
        expectNoDependenciesTables();
      });
    });

    describe('given a list of dependencies and ok report', () => {
      beforeEach(async () => {
        setStateLoaded();

        await nextTick();
      });

      it('shows the dependencies table with the correct props', () => {
        expectHeader();
        expectDependenciesTable();
      });

      describe('export functionality', () => {
        it('has a button to perform an async export of the dependency list', () => {
          expect(findExportButton().attributes('icon')).toBe('export');

          findExportButton().vm.$emit('click');

          expect(store.dispatch).toHaveBeenCalledWith(`${allNamespace}/fetchExport`);
        });

        describe.each`
          namespaceType             | expectedTooltip
          ${NAMESPACE_ORGANIZATION} | ${s__('Dependencies|Export as CSV')}
          ${NAMESPACE_PROJECT}      | ${s__('Dependencies|Export as JSON')}
          ${NAMESPACE_GROUP}        | ${s__('Dependencies|Export as JSON')}
        `('with namespaceType set to $namespaceType', ({ namespaceType, expectedTooltip }) => {
          beforeEach(async () => {
            factory({
              provide: { namespaceType },
            });
            setStateLoaded();
            await nextTick();
          });

          it('shows a tooltip for a CSV export', () => {
            expect(findExportButton().attributes('title')).toBe(expectedTooltip);
          });
        });

        describe('with fetching in progress', () => {
          beforeEach(() => {
            store.state[allNamespace].fetchingInProgress = true;
          });

          it('sets the icon to match the loading icon', () => {
            expect(findExportButton().attributes()).toMatchObject({
              icon: '',
              loading: 'true',
            });
          });
        });
      });

      describe('with namespaceType set to group', () => {
        beforeEach(async () => {
          mock
            .onGet(basicAppProps.endpoint)
            .reply(HTTP_STATUS_OK, { dependencies: [], report: { status: REPORT_STATUS.OK } });
          factory({ provide: { namespaceType: 'group' } });

          await nextTick();
        });

        it('does not show a link to the latest job', () => {
          expect(findHeaderJobLink().exists()).toBe(false);
        });

        it('does not show when the last job ran', () => {
          expect(findTimeAgoMessage().exists()).toBe(false);
        });
      });

      it('shows a link to the latest job', () => {
        expect(findHeaderJobLink().attributes('href')).toBe('/jobs/foo/321');
      });

      it('shows when the last job ran', () => {
        expect(findTimeAgoMessage().text()).toBe('• 1 week ago');
      });

      it('shows a link to the dependencies documentation page', () => {
        expect(findHeaderHelpLink().attributes('href')).toBe(TEST_HOST);
      });

      it('passes the correct namespace to dependencies actions component', () => {
        expectComponentWithProps(DependenciesActions, { namespace: allNamespace });
      });

      describe('given the user has public permissions', () => {
        beforeEach(async () => {
          store.state[allNamespace].reportInfo.generatedAt = '';
          store.state[allNamespace].reportInfo.jobPath = '';

          await nextTick();
        });

        it('shows the header', () => {
          expectHeader();
        });

        it('does not show when the last job ran', () => {
          expect(findHeader().text()).not.toContain('1 week ago');
        });

        it('does not show a link to the latest job', () => {
          expect(findHeaderJobLink().exists()).toBe(false);
        });
      });
    });

    describe('given the dependency list job failed', () => {
      beforeEach(async () => {
        setStateJobFailed();

        await nextTick();
      });

      it('passes the correct props to the job failure alert', () => {
        expectComponentWithProps(DependencyListJobFailedAlert, {
          jobPath: '/jobs/foo/321',
        });
      });

      it('shows the dependencies table with the correct props', expectDependenciesTable);

      describe('when the job failure alert emits the dismiss event', () => {
        beforeEach(async () => {
          const alertWrapper = findJobFailedAlert();
          alertWrapper.vm.$emit('dismiss');
          await nextTick();
        });

        it('does not render the job failure alert', () => {
          expect(findJobFailedAlert().exists()).toBe(false);
        });
      });
    });

    describe('given a dependency list which is known to be incomplete', () => {
      beforeEach(async () => {
        setStateListIncomplete();

        await nextTick();
      });

      it('passes the correct props to the incomplete-list alert', () => {
        expectComponentWithProps(DependencyListIncompleteAlert);
      });

      it('shows the dependencies table with the correct props', expectDependenciesTable);

      describe('when the incomplete-list alert emits the dismiss event', () => {
        beforeEach(async () => {
          const alertWrapper = findIncompleteListAlert();
          alertWrapper.vm.$emit('dismiss');
          await nextTick();
        });

        it('does not render the incomplete-list alert', () => {
          expect(findIncompleteListAlert().exists()).toBe(false);
        });
      });
    });

    describe('given there are no dependencies detected', () => {
      beforeEach(() => {
        setStateNoDependencies();
      });

      it('shows only the empty state', () => {
        expectComponentWithProps(GlEmptyState, { svgPath: basicAppProps.emptyStateSvgPath });
        expectComponentPropsToMatchSnapshot(GlEmptyState);
        expectNoHeader();
        expectNoDependenciesTables();
      });
    });
  });
});
