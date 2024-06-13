import { GlLabel, GlLink, GlTruncate, GlTooltip, GlSprintf } from '@gitlab/ui';
import FrameworkInfoDrawer from 'ee/compliance_dashboard/components/frameworks_report/framework_info_drawer.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createFramework } from 'ee_jest/compliance_dashboard/mock_data';

describe('FrameworkInfoDrawer component', () => {
  let wrapper;

  const GROUP_PATH = 'foo';

  const defaultFramework = createFramework({ id: 1, isDefault: true, projects: 3 });
  const nonDefaultFramework = createFramework({ id: 2 });
  const associatedProjectsCount = defaultFramework.projects.nodes.length;
  const policiesCount =
    defaultFramework.scanExecutionPolicies.nodes.length +
    defaultFramework.scanResultPolicies.nodes.length;

  const findDefaultBadge = () => wrapper.findComponent(GlLabel);
  const findTitle = () => wrapper.findComponent(GlTruncate);
  const findEditFrameworkBtn = () => wrapper.findByText('Edit framework');

  const findDescriptionTitle = () => wrapper.findByTestId('sidebar-description-title');
  const findDescription = () => wrapper.findByTestId('sidebar-description');
  const findProjectsTitle = () => wrapper.findByTestId('sidebar-projects-title');
  const findProjectsLinks = () =>
    wrapper.findByTestId('sidebar-projects').findAllComponents(GlLink);
  const findPoliciesTitle = () => wrapper.findByTestId('sidebar-policies-title');
  const findPoliciesLinks = () =>
    wrapper.findByTestId('sidebar-policies').findAllComponents(GlLink);
  const findTooltip = () => wrapper.findComponent(GlTooltip);

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(FrameworkInfoDrawer, {
      propsData: {
        showDrawer: true,
        ...props,
      },
      stubs: {
        GlSprintf,
        GlLilnk: {
          template: '<a>{{ $attrs.href }}</a>',
        },
      },
      provide,
    });
  };

  describe('default framework display', () => {
    beforeEach(() => {
      createComponent({
        props: {
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
          framework: defaultFramework,
        },
        provide: {
          groupSecurityPoliciesPath: '/group-policies',
        },
      });
    });

    describe('for drawer body content', () => {
      it('renders the title', () => {
        expect(findTitle().props()).toMatchObject({ text: defaultFramework.name, position: 'end' });
      });

      it('renders the default badge', () => {
        expect(findDefaultBadge().exists()).toBe(true);
      });

      it('renders the edit framework button', () => {
        expect(findEditFrameworkBtn().exists()).toBe(true);
      });

      it('renders the Description accordion', () => {
        expect(findDescriptionTitle().text()).toBe(`Description`);
        expect(findDescription().text()).toBe(defaultFramework.description);
      });

      it('renders the Associated Projects accordion', () => {
        expect(findProjectsTitle().text()).toBe(`Associated Projects (${associatedProjectsCount})`);
      });

      it('renders the Associated Projects list', () => {
        expect(findProjectsLinks().wrappers).toHaveLength(3);
        expect(findProjectsLinks().at(0).text()).toContain(defaultFramework.projects.nodes[0].name);
        expect(findProjectsLinks().at(0).attributes('href')).toBe(
          defaultFramework.projects.nodes[0].webUrl,
        );
      });

      it('renders the Policies accordion', () => {
        expect(findPoliciesTitle().text()).toBe(`Policies (${policiesCount})`);
      });

      it('renders the Policies list', () => {
        expect(findPoliciesLinks().wrappers).toHaveLength(policiesCount);
        expect(findPoliciesLinks().at(0).attributes('href')).toBe(
          `/group-policies/${defaultFramework.scanResultPolicies.nodes[0].name}/edit?type=approval_policy`,
        );
      });

      it('does not render edit button tooltip', () => {
        expect(findTooltip().exists()).toBe(false);
      });
    });
  });

  describe('framework display', () => {
    beforeEach(() => {
      createComponent({
        props: {
          framework: nonDefaultFramework,
          groupPath: GROUP_PATH,
          rootAncestor: {
            path: GROUP_PATH,
          },
        },
        provide: {
          groupSecurityPoliciesPath: '/group-policies',
        },
      });
    });

    describe('for drawer body content', () => {
      it('does not renders the default badge', () => {
        expect(findDefaultBadge().exists()).toBe(false);
      });
    });
  });

  describe('when viewing framework in a subgroup', () => {
    beforeEach(() => {
      createComponent({
        props: {
          groupPath: `${GROUP_PATH}/child`,
          rootAncestor: {
            path: GROUP_PATH,
            webUrl: `/web/${GROUP_PATH}`,
            name: 'Root',
          },
          framework: defaultFramework,
        },
        provide: {
          groupSecurityPoliciesPath: '/group-policies',
        },
      });
    });

    it('renders disabled edit framework button', () => {
      expect(findEditFrameworkBtn().props('disabled')).toBe(true);
    });

    it('renders tooltip', () => {
      expect(findTooltip().text()).toMatchInterpolatedText(
        'The compliance framework must be edited in top-level group Root',
      );
    });
  });
});
