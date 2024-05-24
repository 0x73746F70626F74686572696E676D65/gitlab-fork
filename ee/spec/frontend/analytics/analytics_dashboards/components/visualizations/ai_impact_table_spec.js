import { GlLoadingIcon } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupOrProjectProvider from 'ee/analytics/dashboards/components/group_or_project_provider.vue';
import GetGroupOrProjectQuery from 'ee/analytics/dashboards/graphql/get_group_or_project.query.graphql';
import AiImpactTable from 'ee/analytics/analytics_dashboards/components/visualizations/ai_impact_table.vue';
import MetricTable from 'ee/analytics/dashboards/ai_impact/components/metric_table.vue';
import { mockGroup } from 'ee_jest/analytics/dashboards/mock_data';

Vue.use(VueApollo);

describe('AI Impact Table Visualization', () => {
  let wrapper;
  let mockGroupOrProjectRequestHandler;

  const namespace = 'Klaptrap';
  const title = `Metric trends for group: ${namespace}`;

  const createWrapper = () => {
    wrapper = shallowMountExtended(AiImpactTable, {
      apolloProvider: createMockApollo([
        [GetGroupOrProjectQuery, mockGroupOrProjectRequestHandler],
      ]),
      propsData: {
        data: { namespace, title },
      },
      stubs: { GroupOrProjectProvider },
    });
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findMetricTable = () => wrapper.findComponent(MetricTable);

  afterEach(() => {
    mockGroupOrProjectRequestHandler = null;
  });

  describe('when loading', () => {
    beforeEach(() => {
      mockGroupOrProjectRequestHandler = jest.fn().mockImplementation(() => new Promise(() => {}));

      createWrapper();
    });

    it('renders the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not render the metric table', () => {
      expect(findMetricTable().exists()).toBe(false);
    });
  });

  describe('when mounted', () => {
    beforeEach(() => {
      mockGroupOrProjectRequestHandler = jest
        .fn()
        .mockReturnValueOnce({ data: { group: mockGroup, project: null } });

      createWrapper();
    });

    it('does not render the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('resolves the namespace', () => {
      expect(mockGroupOrProjectRequestHandler).toHaveBeenCalledWith({ fullPath: namespace });
    });

    it('renders the metric table', () => {
      expect(findMetricTable().props()).toMatchObject({
        namespace,
        isProject: false,
      });
    });

    it('echos `set-alerts` event from the metric table', () => {
      const payload = { errors: ['one', 'two'] };
      findMetricTable().vm.$emit('set-alerts', payload);

      expect(wrapper.emitted('set-alerts').length).toBe(1);
      expect(wrapper.emitted('set-alerts')[0][0]).toEqual(payload);
    });
  });
});
