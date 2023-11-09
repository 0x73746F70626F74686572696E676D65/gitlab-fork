import { GlSkeletonLoader, GlTableLite } from '@gitlab/ui';
import ProductAnalyticsProjectsUsageTable from 'ee/usage_quotas/product_analytics/components/projects_usage/product_analytics_projects_usage_table.vue';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';

describe('ProductAnalyticsProjectsUsageTable', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findLoadingState = () => wrapper.findComponent(GlSkeletonLoader);
  const findUsageTableWrapper = () => wrapper.findByTestId('projects-usage-table');
  const findUsageTable = () => wrapper.findComponent(GlTableLite);
  const findProjectLink = () => wrapper.findByTestId('project-link');
  const findProjectAvatar = () => wrapper.findComponent(ProjectAvatar);

  const createComponent = (props = {}, mountFn = shallowMountExtended) => {
    wrapper = mountFn(ProductAnalyticsProjectsUsageTable, {
      propsData: {
        ...props,
      },
    });
  };

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({
        isLoading: true,
        projectsUsageData: undefined,
      });
    });

    it('renders the loading state', () => {
      expect(findLoadingState().exists()).toBe(true);
    });

    it('does not render the usage table', () => {
      expect(findUsageTableWrapper().exists()).toBe(false);
    });
  });

  describe('when there is no project data', () => {
    beforeEach(() => {
      createComponent({
        isLoading: false,
        projectsUsageData: [],
      });
    });

    it('does not render the loading state', () => {
      expect(findLoadingState().exists()).toBe(false);
    });

    it('does not render the usage table', () => {
      expect(findUsageTableWrapper().exists()).toBe(false);
    });
  });

  describe('when there is project data', () => {
    const projectsUsageData = [
      {
        id: 1,
        webUrl: '/test-project',
        avatarUrl: '/test-project.jpg',
        name: 'test-project',
        currentEvents: 10,
        previousEvents: 4,
      },
    ];

    beforeEach(() => {
      createComponent(
        {
          isLoading: false,
          projectsUsageData,
        },
        mountExtended,
      );
    });

    it('does not render the loading state', () => {
      expect(findLoadingState().exists()).toBe(false);
    });

    it('renders the usage table', () => {
      expect(findUsageTable().exists()).toBe(true);
    });

    it('renders a link to the project', () => {
      expect(findProjectLink().attributes('href')).toBe('/test-project');
    });

    it('renders the project avatar', () => {
      expect(findProjectAvatar().props()).toMatchObject(
        expect.objectContaining({
          projectId: 1,
          projectAvatarUrl: '/test-project.jpg',
          projectName: 'test-project',
          alt: 'test-project',
        }),
      );
    });

    it('renders a note about excluded projects', () => {
      expect(findUsageTableWrapper().text()).toContain(
        'This table excludes projects that do not have product analytics onboarded.',
      );
    });
  });
});
