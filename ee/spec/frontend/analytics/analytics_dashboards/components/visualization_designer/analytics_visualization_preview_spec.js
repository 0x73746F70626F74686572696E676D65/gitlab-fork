import { safeDump } from 'js-yaml';
import AnalyticsVisualizationPreview from 'ee/analytics/analytics_dashboards/components/visualization_designer/analytics_visualization_preview.vue';
import AiCubeQueryFeedback from 'ee/analytics/analytics_dashboards/components/visualization_designer/ai_cube_query_feedback.vue';

import {
  PANEL_DISPLAY_TYPES,
  PANEL_VISUALIZATION_HEIGHT,
} from 'ee/analytics/analytics_dashboards/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DataTable from 'ee/analytics/analytics_dashboards/components/visualizations/data_table.vue';
import { convertToTableFormat } from 'ee/analytics/analytics_dashboards/data_sources/cube_analytics';
import { TEST_VISUALIZATION } from '../../mock_data';

jest.mock('js-yaml', () => ({
  safeDump: jest.fn().mockImplementation(() => 'yaml: mock-code'),
}));

describe('AnalyticsVisualizationPreview', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findDataButton = () => wrapper.findByTestId('select-data-button');
  const findVisualizationButton = () => wrapper.findByTestId('select-visualization-button');
  const findCodeButton = () => wrapper.findByTestId('select-code-button');
  const findAiCubeQueryFeedback = () => wrapper.findComponent(AiCubeQueryFeedback);
  const findDataTable = () => wrapper.findComponent(DataTable);

  const selectDisplayType = jest.fn();

  const resultVisualization = TEST_VISUALIZATION();
  const resultSet = { tableColumns: () => [], tablePivot: () => [] };

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(AnalyticsVisualizationPreview, {
      propsData: {
        selectedVisualizationType: '',
        displayType: '',
        selectDisplayType,
        isQueryPresent: false,
        loading: false,
        resultSet,
        resultVisualization,
        aiPromptCorrelationId: null,
        ...props,
      },
    });
  };

  describe('when mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should render measurement headline', () => {
      expect(wrapper.findByTestId('measurement-hl').text()).toBe('Start by choosing a metric');
    });
  });

  describe('when loading', () => {
    beforeEach(() => {
      createWrapper({ isQueryPresent: true, loading: true });
    });

    it('should render loading icon', () => {
      expect(wrapper.findByTestId('loading-icon').exists()).toBe(true);
    });
  });

  describe('when it has a resultSet', () => {
    describe('default behaviour', () => {
      beforeEach(() => {
        createWrapper({
          isQueryPresent: true,
        });
      });

      it('should render overview buttons', () => {
        expect(findDataButton().exists()).toBe(true);
        expect(findVisualizationButton().exists()).toBe(true);
        expect(findCodeButton().exists()).toBe(true);
      });

      it('should be able to select data section', () => {
        findDataButton().vm.$emit('click');
        expect(wrapper.emitted('selectedDisplayType')).toEqual([[PANEL_DISPLAY_TYPES.DATA]]);
      });

      it('should be able to select visualization section', () => {
        findVisualizationButton().vm.$emit('click');
        expect(wrapper.emitted('selectedDisplayType')).toEqual([
          [PANEL_DISPLAY_TYPES.VISUALIZATION],
        ]);
      });

      it('should be able to select code section', () => {
        findCodeButton().vm.$emit('click');
        expect(wrapper.emitted('selectedDisplayType')).toEqual([[PANEL_DISPLAY_TYPES.CODE]]);
      });
    });

    describe('when there is an AI prompt correlation id', () => {
      beforeEach(() => {
        createWrapper({
          isQueryPresent: true,
          aiPromptCorrelationId: 'some-prompt-id',
        });
      });

      it('should render the AI cube query feedback component', () => {
        expect(findAiCubeQueryFeedback().props()).toMatchObject({
          correlationId: 'some-prompt-id',
        });
      });
    });

    describe('when there is no AI prompt correlation id', () => {
      beforeEach(() => {
        createWrapper({
          isQueryPresent: true,
          aiPromptCorrelationId: null,
        });
      });

      it('should not render the AI cube query feedback component', () => {
        expect(findAiCubeQueryFeedback().exists()).toBe(false);
      });
    });
  });

  describe('resultSet and data is selected', () => {
    beforeEach(() => {
      createWrapper({
        isQueryPresent: true,
        displayType: PANEL_DISPLAY_TYPES.DATA,
      });
    });

    it('renders the data table', () => {
      expect(findDataTable().props('data')).toStrictEqual(convertToTableFormat(resultSet));
    });

    it('renders data table wrapper', () => {
      expect(wrapper.findByTestId('preview-datatable-wrapper').attributes('style')).toBe(
        `height: ${PANEL_VISUALIZATION_HEIGHT};`,
      );
    });
  });

  describe('resultSet and visualization is selected', () => {
    beforeEach(() => {
      createWrapper({
        title: 'Hello world',
        isQueryPresent: true,
        displayType: PANEL_DISPLAY_TYPES.VISUALIZATION,
        selectedVisualizationType: 'LineChart',
      });
    });

    it('should render visualization', () => {
      const preview = wrapper.findByTestId('preview-visualization');

      expect(preview.attributes('style')).toBe(`height: ${PANEL_VISUALIZATION_HEIGHT};`);
      expect(preview.props()).toMatchObject({
        title: 'Hello world',
        visualization: resultVisualization,
      });
    });
  });

  describe('resultSet and code is selected', () => {
    beforeEach(() => {
      createWrapper({
        isQueryPresent: true,
        displayType: PANEL_DISPLAY_TYPES.CODE,
      });
    });

    it('should render Code', () => {
      expect(safeDump).toHaveBeenCalledWith(resultVisualization);
      expect(wrapper.findByTestId('preview-code').text()).toBe('yaml: mock-code');
    });
  });
});
