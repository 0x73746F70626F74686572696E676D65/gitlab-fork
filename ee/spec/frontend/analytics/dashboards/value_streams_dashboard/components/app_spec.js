import { GlLink, GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  DASHBOARD_TITLE,
  DASHBOARD_DESCRIPTION,
  DASHBOARD_DOCS_LINK,
} from 'ee/analytics/dashboards/constants';
import * as yamlConfigUtils from 'ee/analytics/dashboards/yaml_utils';
import Component from 'ee/analytics/dashboards/value_streams_dashboard/components/app.vue';
import DoraVisualization from 'ee/analytics/dashboards/components/dora_visualization.vue';
import DoraPerformersScoreCard from 'ee/analytics/dashboards/dora_performers_score/components/dora_performers_score_card.vue';
import FeedbackBanner from 'ee/analytics/dashboards/components/value_stream_feedback_banner.vue';

describe('Executive dashboard app', () => {
  let wrapper;
  const fullPath = 'groupFullPath';
  const testPaths = ['group', 'group/a', 'group/b', 'group/c', 'group/d', 'group/e'];
  const testPanels = testPaths.map((namespace) => ({ data: { namespace } }));

  const createWrapper = async ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(Component, {
      propsData: {
        fullPath,
        ...props,
      },
    });

    await waitForPromises();
  };

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findAlert = () => wrapper.findByTestId('alert-error');
  const findTitle = () => wrapper.findByTestId('dashboard-title');
  const findDescription = () => wrapper.findByTestId('dashboard-description');
  const findDoraVisualizations = () => wrapper.findAllComponents(DoraVisualization);
  const findDoraPerformersScoreCards = () => wrapper.findAllComponents(DoraPerformersScoreCard);

  it('shows a loading skeleton when fetching the YAML config', () => {
    createWrapper();
    expect(findSkeletonLoader().exists()).toBe(true);
  });

  it('shows the feedback banner', () => {
    createWrapper();
    expect(wrapper.findComponent(FeedbackBanner).exists()).toBe(true);
  });

  describe('default config', () => {
    it('renders the page title', async () => {
      await createWrapper();
      expect(findTitle().text()).toBe(DASHBOARD_TITLE);
    });

    it('renders the description', async () => {
      await createWrapper();
      expect(findDescription().text()).toContain(DASHBOARD_DESCRIPTION);
      expect(findDescription().findComponent(GlLink).attributes('href')).toBe(DASHBOARD_DOCS_LINK);
    });

    it('renders a visualization for the group fullPath', async () => {
      await createWrapper();
      const charts = findDoraVisualizations();
      expect(charts.length).toBe(1);

      const [chart] = charts.wrappers;
      expect(chart.props()).toMatchObject({ data: { namespace: fullPath } });
    });

    it('renders dora performers card for the group fullPath', async () => {
      await createWrapper();
      const cards = findDoraPerformersScoreCards();
      expect(cards.length).toBe(1);

      const [card] = cards.wrappers;
      expect(card.props()).toMatchObject({ data: { namespace: fullPath } });
    });

    it('queryPaths are shown in addition to the group visualization', async () => {
      const queryPaths = [
        { namespace: 'group/one', isProject: false },
        { namespace: 'group/two', isProject: false },
        { namespace: 'group/three', isProject: false },
      ];
      const groupFullPath = { namespace: fullPath };
      await createWrapper({ props: { queryPaths } });

      const charts = findDoraVisualizations();
      expect(charts.length).toBe(4);

      [groupFullPath, ...queryPaths].forEach(({ namespace }, index) => {
        expect(charts.wrappers[index].props()).toMatchObject({ data: { namespace } });
      });
    });

    it('does not render group-only visualizations for project queryPaths', async () => {
      const groupQueryPaths = [
        { namespace: 'group/one', isProject: false },
        { namespace: 'group/two', isProject: false },
      ];
      const projectQueryPath = { namespace: 'project/one', isProject: true };
      const groupFullPath = { namespace: fullPath };
      const queryPaths = [projectQueryPath, ...groupQueryPaths];

      await createWrapper({ props: { queryPaths } });

      const cards = findDoraPerformersScoreCards();
      expect(cards).toHaveLength(groupQueryPaths.length + 1);

      [groupFullPath, ...groupQueryPaths].forEach(({ namespace }, index) => {
        expect(cards.wrappers[index].props()).toMatchObject({ data: { namespace } });
      });
    });
  });

  describe('YAML config', () => {
    const yamlConfigProject = { id: 3, fullPath: 'group/project' };
    const panels = [
      { title: 'One', data: { namespace: 'group/one' } },
      { data: { namespace: 'group/two' } },
    ];

    it('falls back to the default config with an alert if it fails to fetch', async () => {
      jest.spyOn(yamlConfigUtils, 'fetchYamlConfig').mockResolvedValue(null);
      await createWrapper({ props: { yamlConfigProject } });
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toBe('Failed to load YAML config from Project: group/project');
    });

    it('renders a custom page title', async () => {
      const title = 'TEST TITLE';
      jest.spyOn(yamlConfigUtils, 'fetchYamlConfig').mockResolvedValue({ title });
      await createWrapper({ props: { yamlConfigProject } });
      expect(findTitle().text()).toBe(title);
    });

    it('renders a custom description', async () => {
      const description = 'TEST DESCRIPTION';
      jest.spyOn(yamlConfigUtils, 'fetchYamlConfig').mockResolvedValue({ description });
      await createWrapper({ props: { yamlConfigProject } });
      expect(findDescription().text()).toBe(description);
      expect(findDescription().findComponent(GlLink).exists()).toBe(false);
    });

    it('renders a visualization for each panel', async () => {
      jest.spyOn(yamlConfigUtils, 'fetchYamlConfig').mockResolvedValue({ panels });
      await createWrapper({ props: { yamlConfigProject } });

      const charts = findDoraVisualizations();
      expect(charts.length).toBe(2);

      expect(charts.wrappers[0].props()).toMatchObject(panels[0]);
      expect(charts.wrappers[1].props()).toMatchObject(panels[1]);
    });

    it('can render any number of visualizations', async () => {
      jest.spyOn(yamlConfigUtils, 'fetchYamlConfig').mockResolvedValue({ panels: testPanels });
      await createWrapper({ props: { yamlConfigProject } });

      const charts = findDoraVisualizations();
      expect(charts.length).toBe(6);
    });

    it('queryPaths override the panels list', async () => {
      const queryPaths = [
        { namespace: 'group/one', isProject: false },
        { namespace: 'group/two', isProject: false },
        { namespace: 'group/three', isProject: false },
      ];
      const groupFullPath = { namespace: fullPath };

      jest.spyOn(yamlConfigUtils, 'fetchYamlConfig').mockResolvedValue({ panels });
      await createWrapper({ props: { yamlConfigProject, queryPaths } });

      const charts = findDoraVisualizations();
      expect(charts.length).toBe(4);

      [groupFullPath, ...queryPaths].forEach(({ namespace }, index) => {
        expect(charts.wrappers[index].props()).toMatchObject({ data: { namespace } });
      });
    });
  });
});
