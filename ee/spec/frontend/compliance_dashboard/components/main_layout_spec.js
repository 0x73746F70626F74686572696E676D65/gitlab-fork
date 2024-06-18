import { mount } from '@vue/test-utils';
import { GlTabs } from '@gitlab/ui';
import { extendedWrapper, shallowMountExtended } from 'helpers/vue_test_utils_helper';

import { __ } from '~/locale';
import MainLayout from 'ee/compliance_dashboard/components/main_layout.vue';
import ReportHeader from 'ee/compliance_dashboard/components/shared/report_header.vue';
import { stubComponent } from 'helpers/stub_component';
import { mockTracking } from 'helpers/tracking_helper';
import {
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_VIOLATIONS,
} from 'ee/compliance_dashboard/constants';

describe('ComplianceReportsApp component', () => {
  let wrapper;
  let trackingSpy;
  const defaultInjects = {
    groupPath: 'group-path',
    mergeCommitsCsvExportPath: '/csv',
    projectFrameworksCsvExportPath: '/project_frameworks_report.csv',
    violationsCsvExportPath: '/compliance_violation_reports.csv',
    adherencesCsvExportPath: '/compliance_standards_adherences.csv',
    frameworksCsvExportPath: '/compliance_frameworks_report.csv',
  };

  const findHeader = () => wrapper.findComponent(ReportHeader);
  const findMergeCommitsExportButton = () => wrapper.findByText('Export chain of custody report');
  const findViolationsExportButton = () => wrapper.findByText('Export violations report');
  const findAdherencesExportButton = () => wrapper.findByText('Export standards adherence report');
  const findFrameworksExportButton = () => wrapper.findByText('Export frameworks report');
  const findProjectFrameworksExportButton = () =>
    wrapper.findByText('Export list of project frameworks');
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findProjectsTab = () => wrapper.findByTestId('projects-tab-content');
  const findProjectFrameworksTab = () => wrapper.findByTestId('frameworks-tab-content');
  const findViolationsTab = () => wrapper.findByTestId('violations-tab-content');
  const findStandardsAdherenceTab = () => wrapper.findByTestId('standards-adherence-tab-content');

  const createComponent = (
    mountFn = shallowMountExtended,
    mocks = {},
    provide = {},
    props = {},
  ) => {
    return extendedWrapper(
      mountFn(MainLayout, {
        mocks: {
          $router: { push: jest.fn() },
          $route: {
            name: ROUTE_VIOLATIONS,
          },
          ...mocks,
        },
        propsData: {
          availableTabs: [
            ROUTE_STANDARDS_ADHERENCE,
            ROUTE_VIOLATIONS,
            ROUTE_PROJECTS,
            ROUTE_FRAMEWORKS,
          ],
          ...props,
        },
        stubs: {
          'router-view': stubComponent({}),
        },
        provide: {
          ...defaultInjects,
          ...provide,
        },
      }),
    );
  };

  describe('adherence standards report', () => {
    beforeEach(() => {
      wrapper = createComponent(mount);
    });

    it('renders the standards adherence report tab', () => {
      expect(findStandardsAdherenceTab().exists()).toBe(true);
    });

    it('renders the adherences export button', () => {
      expect(findAdherencesExportButton().exists()).toBe(true);
    });

    it('does not render the adherences export button when there is no CSV path', () => {
      wrapper = createComponent(mount, {}, { adherencesCsvExportPath: null });
      expect(findAdherencesExportButton().exists()).toBe(false);
    });
  });

  describe('violations report', () => {
    beforeEach(() => {
      wrapper = createComponent(mount);
    });

    it('renders the violations report tab', () => {
      expect(findViolationsTab().exists()).toBe(true);
    });

    it('passes the expected values to the header', () => {
      expect(findHeader().props()).toMatchObject({
        heading: __('Compliance center'),
        subheading: __(
          'Report and manage standards adherence, violations, and compliance frameworks for the group.',
        ),
        documentationPath: '/help/user/compliance/compliance_center/index.md',
      });
    });

    it('renders the violations export button', () => {
      expect(findViolationsExportButton().exists()).toBe(true);
    });

    it('does not render the merge commit export button when there is no CSV path', () => {
      wrapper = createComponent(mount, {}, { mergeCommitsCsvExportPath: null });
      findTabs().vm.$emit('input', 0);

      expect(findMergeCommitsExportButton().exists()).toBe(false);
    });

    it('does not render the violations export button when there is no CSV path', () => {
      wrapper = createComponent(mount, {}, { violationsCsvExportPath: null });
      findTabs().vm.$emit('input', 0);

      expect(findViolationsExportButton().exists()).toBe(false);
    });
  });

  describe('projects report', () => {
    beforeEach(() => {
      wrapper = createComponent(mount, {
        $route: {
          name: ROUTE_PROJECTS,
        },
      });
    });

    it('renders the projects report tab', () => {
      expect(findProjectsTab().exists()).toBe(true);
    });

    it('passes the expected values to the header', () => {
      expect(findHeader().props()).toMatchObject({
        heading: __('Compliance center'),
        subheading: __(
          'Report and manage standards adherence, violations, and compliance frameworks for the group.',
        ),
        documentationPath: '/help/user/compliance/compliance_center/index.md',
      });
    });

    it('renders the project frameworks export button', () => {
      expect(findProjectFrameworksExportButton().exists()).toBe(true);
    });

    it('does not render the projects export button when there is no CSV path', () => {
      wrapper = createComponent(
        mount,
        {
          $route: {
            name: ROUTE_FRAMEWORKS,
          },
        },
        { projectFrameworksCsvExportPath: null },
      );

      expect(findProjectFrameworksExportButton().exists()).toBe(false);
    });
  });

  describe('frameworks report', () => {
    beforeEach(() => {
      wrapper = createComponent(mount, {
        $route: {
          name: ROUTE_PROJECTS,
        },
      });
    });

    it('renders the projects tab', () => {
      expect(findProjectsTab().exists()).toBe(true);
    });

    it('renders the frameworks report tab', () => {
      expect(findProjectFrameworksTab().exists()).toBe(true);
    });

    it('renders the frameworks export button', () => {
      expect(findFrameworksExportButton().exists()).toBe(true);
    });

    it('does not render the adherences export button when there is no CSV path', () => {
      wrapper = createComponent(mount, {}, { frameworksCsvExportPath: null });
      expect(findFrameworksExportButton().exists()).toBe(false);
    });
  });

  describe.each`
    route                        | finder
    ${ROUTE_STANDARDS_ADHERENCE} | ${findStandardsAdherenceTab}
    ${ROUTE_VIOLATIONS}          | ${findViolationsTab}
    ${ROUTE_PROJECTS}            | ${findProjectsTab}
    ${ROUTE_FRAMEWORKS}          | ${findProjectFrameworksTab}
  `('for $route', ({ route, finder }) => {
    const allTabs = [ROUTE_STANDARDS_ADHERENCE, ROUTE_VIOLATIONS, ROUTE_PROJECTS, ROUTE_FRAMEWORKS];
    it('does not render the tab when relevant tab is not passed', () => {
      wrapper = createComponent(
        mount,
        {},
        {},
        {
          availableTabs: allTabs.filter((r) => r !== route),
        },
      );

      expect(finder().exists()).toBe(false);
    });

    it('render the tab when relevant tab is passed', () => {
      wrapper = createComponent(
        mount,
        {},
        {},
        {
          availableTabs: [route],
        },
      );

      expect(finder().exists()).toBe(true);
    });
  });

  describe('tracking', () => {
    beforeEach(() => {
      wrapper = createComponent(mount, {
        $route: {
          name: ROUTE_VIOLATIONS,
        },
      });
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
    });

    it('tracks clicks on framework tab', () => {
      findProjectFrameworksTab().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_report_tab', {
        label: 'frameworks',
      });
    });
    it('tracks clicks on projects tab', () => {
      findProjectsTab().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_report_tab', {
        label: 'projects',
      });
    });
    it('tracks clicks on adherence tab', () => {
      findStandardsAdherenceTab().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_report_tab', {
        label: 'standards_adherence',
      });
    });
    it('tracks clicks on violations tab', () => {
      // Can't navigate to a page we are already on so use a different tab to start with
      wrapper = createComponent(mount, {
        $route: {
          name: ROUTE_FRAMEWORKS,
        },
      });
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      findViolationsTab().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_report_tab', {
        label: 'violations',
      });
    });
  });
});
