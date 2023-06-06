import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { UNITS } from 'ee/analytics/dashboards/constants';
import {
  percentChange,
  formatMetric,
  hasDoraMetricValues,
  generateDoraTimePeriodComparisonTable,
  generateSparklineCharts,
  mergeSparklineCharts,
  hasTrailingDecimalZero,
  generateDateRanges,
  generateChartTimePeriods,
  generateDashboardTableFields,
} from 'ee/analytics/dashboards/utils';
import { CHANGE_FAILURE_RATE, LEAD_TIME_FOR_CHANGES } from 'ee/api/dora_api';
import { LEAD_TIME_METRIC_TYPE, CYCLE_TIME_METRIC_TYPE } from '~/api/analytics_api';
import {
  mockMonthToDateTimePeriod,
  mockPreviousMonthTimePeriod,
  mockTwoMonthsAgoTimePeriod,
  mockThreeMonthsAgoTimePeriod,
  mockComparativeTableData,
  mockChartsTimePeriods,
  mockChartData,
  mockSubsetChartsTimePeriods,
  mockSubsetChartData,
  MOCK_TABLE_TIME_PERIODS,
  MOCK_CHART_TIME_PERIODS,
  MOCK_DASHBOARD_TABLE_FIELDS,
} from './mock_data';

describe('Analytics Dashboards utils', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('percentChange', () => {
    it.each`
      current | previous | result
      ${10}   | ${20}    | ${-0.5}
      ${5}    | ${2}     | ${1.5}
      ${5}    | ${0}     | ${0}
      ${0}    | ${5}     | ${0}
    `('calculates the percentage change given 2 numbers', ({ current, previous, result }) => {
      expect(percentChange({ current, previous })).toBe(result);
    });
  });

  describe.each([
    { units: UNITS.PER_DAY, suffix: '/d' },
    { units: UNITS.DAYS, suffix: ' d' },
    { units: UNITS.PERCENT, suffix: '%' },
  ])('formatMetric(*, $units)', ({ units, suffix }) => {
    it.each`
      value      | result
      ${0}       | ${'0.0'}
      ${10}      | ${'10.0'}
      ${-10}     | ${'-10.0'}
      ${1}       | ${'1.0'}
      ${-1}      | ${'-1.0'}
      ${0.1}     | ${'0.1'}
      ${-0.99}   | ${'-0.99'}
      ${0.099}   | ${'0.099'}
      ${-0.01}   | ${'-0.01'}
      ${0.0099}  | ${'0.0099'}
      ${-0.0001} | ${'-0.0001'}
    `('returns $result for a metric with the value $value', ({ value, result }) => {
      expect(formatMetric(value, units)).toBe(`${result}${suffix}`);
    });
  });

  describe('hasTrailingDecimalZero', () => {
    it.each`
      value         | result
      ${'-10.0/d'}  | ${false}
      ${'0.099/d'}  | ${false}
      ${'0.0099%'}  | ${false}
      ${'0.10%'}    | ${true}
      ${'-0.010 d'} | ${true}
    `('returns $result for value $value', ({ value, result }) => {
      expect(hasTrailingDecimalZero(value)).toBe(result);
    });
  });

  describe('generateDoraTimePeriodComparisonTable', () => {
    const timePeriods = [
      mockMonthToDateTimePeriod,
      mockPreviousMonthTimePeriod,
      mockTwoMonthsAgoTimePeriod,
      mockThreeMonthsAgoTimePeriod,
    ];

    it('calculates the changes between the 2 time periods', () => {
      const tableData = generateDoraTimePeriodComparisonTable({ timePeriods });
      expect(tableData).toEqual(mockComparativeTableData);
    });

    it('returns the comparison table fields + metadata for each row', () => {
      generateDoraTimePeriodComparisonTable({ timePeriods }).forEach((row) => {
        expect(Object.keys(row)).toEqual([
          'invertTrendColor',
          'metric',
          'valueLimit',
          'thisMonth',
          'lastMonth',
          'twoMonthsAgo',
        ]);
      });
    });

    it('does not include metrics that were in excludeMetrics', () => {
      const excludeMetrics = [LEAD_TIME_METRIC_TYPE, CYCLE_TIME_METRIC_TYPE];
      const tableData = generateDoraTimePeriodComparisonTable({ timePeriods, excludeMetrics });

      const metrics = tableData.map(({ metric }) => metric.identifier);
      expect(metrics).not.toEqual(expect.arrayContaining(excludeMetrics));
    });
  });

  describe('generateSparklineCharts', () => {
    let res = {};

    beforeEach(() => {
      res = generateSparklineCharts(mockChartsTimePeriods);
    });

    it('returns the chart data for each metric', () => {
      expect(res).toEqual(mockChartData);
    });

    describe('with metrics keys', () => {
      beforeEach(() => {
        res = generateSparklineCharts(mockSubsetChartsTimePeriods);
      });

      it('returns 0 for each missing metric', () => {
        expect(res).toEqual(mockSubsetChartData);
      });
    });
  });

  describe('mergeSparklineCharts', () => {
    it('returns the table data with the additive chart data', () => {
      const chart = { data: [1, 2, 3] };
      const rowNoChart = { metric: { identifier: 'noChart' } };
      const rowWithChart = { metric: { identifier: 'withChart' } };

      expect(mergeSparklineCharts([rowNoChart, rowWithChart], { withChart: chart })).toEqual([
        rowNoChart,
        { ...rowWithChart, chart },
      ]);
    });
  });

  describe('hasDoraMetricValues', () => {
    it('returns false if only non-DORA metrics contain a value > 0', () => {
      const timePeriods = [{ nonDoraMetric: { value: 100 } }];
      expect(hasDoraMetricValues(timePeriods)).toBe(false);
    });

    it('returns false if all DORA metrics contain a non-numerical value', () => {
      const timePeriods = [{ [LEAD_TIME_FOR_CHANGES]: { value: 'YEET' } }];
      expect(hasDoraMetricValues(timePeriods)).toBe(false);
    });

    it('returns false if all DORA metrics contain a value == 0', () => {
      const timePeriods = [{ [LEAD_TIME_FOR_CHANGES]: { value: 0 } }];
      expect(hasDoraMetricValues(timePeriods)).toBe(false);
    });

    it('returns true if any DORA metrics contain a value > 0', () => {
      const timePeriods = [
        {
          [LEAD_TIME_FOR_CHANGES]: { value: 0 },
          [CHANGE_FAILURE_RATE]: { value: 100 },
        },
      ];
      expect(hasDoraMetricValues(timePeriods)).toBe(true);
    });
  });

  describe('generateDateRanges', () => {
    it('return correct value', () => {
      const now = MOCK_TABLE_TIME_PERIODS[0].end;
      expect(generateDateRanges(now)).toEqual(MOCK_TABLE_TIME_PERIODS);
    });

    it('return incorrect value', () => {
      const now = MOCK_TABLE_TIME_PERIODS[2].start;
      expect(generateDateRanges(now)).not.toEqual(MOCK_TABLE_TIME_PERIODS);
    });
  });

  describe('generateChartTimePeriods', () => {
    it('return correct value', () => {
      const now = MOCK_TABLE_TIME_PERIODS[0].end;
      expect(generateChartTimePeriods(now)).toEqual(MOCK_CHART_TIME_PERIODS);
    });

    it('return incorrect value', () => {
      const now = MOCK_TABLE_TIME_PERIODS[2].start;
      expect(generateChartTimePeriods(now)).not.toEqual(MOCK_CHART_TIME_PERIODS);
    });
  });

  describe('generateDashboardTableFields', () => {
    it('return correct value', () => {
      const now = MOCK_TABLE_TIME_PERIODS[0].end;
      expect(generateDashboardTableFields(now)).toEqual(MOCK_DASHBOARD_TABLE_FIELDS);
    });

    it('return incorrect value', () => {
      const now = MOCK_TABLE_TIME_PERIODS[2].start;
      expect(generateDashboardTableFields(now)).not.toEqual(MOCK_DASHBOARD_TABLE_FIELDS);
    });
  });
});
