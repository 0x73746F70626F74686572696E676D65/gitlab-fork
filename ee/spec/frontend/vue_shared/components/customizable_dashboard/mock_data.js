import { __ } from '~/locale';
import { getUniquePanelId } from 'ee/vue_shared/components/customizable_dashboard/utils';

const cubeLineChart = {
  type: 'LineChart',
  slug: 'cube_line_chart',
  title: 'Cube line chart',
  data: {
    type: 'cube_analytics',
    query: {
      users: {
        measures: ['TrackedEvents.count'],
        dimensions: ['TrackedEvents.eventType'],
      },
    },
  },
  options: {
    xAxis: {
      name: 'Time',
      type: 'time',
    },
    yAxis: {
      name: 'Counts',
    },
  },
};

export const dashboard = {
  id: 'analytics_overview',
  slug: 'analytics_overview',
  title: 'Analytics Overview',
  description: 'This is a dashboard',
  userDefined: true,
  panels: [
    {
      title: __('Test A'),
      gridAttributes: { width: 3, height: 3 },
      visualization: cubeLineChart,
      queryOverrides: null,
      id: getUniquePanelId(),
    },
    {
      title: __('Test B'),
      gridAttributes: { width: 2, height: 4, minHeight: 2, minWidth: 2 },
      visualization: cubeLineChart,
      queryOverrides: {
        limit: 200,
      },
      id: getUniquePanelId(),
    },
  ],
};

export const builtinDashboard = {
  title: 'Analytics Overview',
  description: 'This is a built-in description',
  panels: [
    {
      title: __('Test A'),
      gridAttributes: { width: 3, height: 3 },
      visualization: cubeLineChart,
      queryOverrides: {},
      id: getUniquePanelId(),
    },
  ],
};

export const betaDashboard = {
  title: 'Test Dashboard',
  description: 'This dashboard is a work-in-progress',
  status: 'beta',
  panels: [
    {
      title: __('Test A'),
      gridAttributes: { width: 3, height: 3 },
      visualization: cubeLineChart,
      queryOverrides: {},
      id: getUniquePanelId(),
    },
  ],
};

export const mockDateRangeFilterChangePayload = {
  startDate: new Date('2016-01-01'),
  endDate: new Date('2016-02-01'),
  dateRangeOption: 'foo',
};

export const mockPanel = {
  title: __('Test A'),
  gridAttributes: {
    width: 1,
    height: 2,
    xPos: 0,
    yPos: 3,
    minWidth: 1,
    minHeight: 2,
    maxWidth: 1,
    maxHeight: 2,
  },
  visualization: cubeLineChart,
  queryOverrides: {},
  id: getUniquePanelId(),
};
