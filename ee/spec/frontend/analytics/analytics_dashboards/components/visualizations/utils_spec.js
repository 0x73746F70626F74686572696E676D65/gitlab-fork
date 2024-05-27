import {
  formatVisualizationTooltipTitle,
  formatVisualizationValue,
  humanizeDisplayUnit,
} from 'ee/analytics/analytics_dashboards/components/visualizations/utils';

describe('visualization utils', () => {
  describe('formatVisualizationValue', () => {
    describe('when the value is not numeric', () => {
      it.each(['abc', true, null, undefined])('returns the value without modification', (value) => {
        expect(formatVisualizationValue(value)).toBe(value);
      });
    });

    describe('when the value is an ISO date string', () => {
      it.each`
        dateStr                      | expected
        ${'2024-04-19T00:00:00.000'} | ${'Apr 19, 2024 12:00am UTC'}
        ${'2023-11-12T17:43:11.987'} | ${'Nov 12, 2023 5:43pm UTC'}
      `('returns date formatted as "$expected"', ({ dateStr, expected }) => {
        expect(formatVisualizationValue(dateStr)).toBe(expected);
      });
    });

    describe('when the value is numeric', () => {
      it.each([
        [123, '123'],
        [1234, '1,234'],
        [-123, '-123'],
        [123.12, '123'],
        [-1234.12, '-1,234'],
        ['1234567890', '1,234,567,890'],
        ['1234567890.123456', '1,234,567,890'],
        ['-1234567890', '-1,234,567,890'],
        ['-1234567890.123456', '-1,234,567,890'],
      ])('returns the formatted value', (value, expected) => {
        expect(formatVisualizationValue(value)).toBe(expected);
      });
    });
  });

  describe('formatVisualizationTooltipTitle', () => {
    describe('when params object is expected structure', () => {
      it.each`
        value                        | expected
        ${'2024-04-19T00:00:00.000'} | ${'Apr 19, 2024 12:00am UTC (AxisName)'}
        ${'2023-11-12T17:43:11.987'} | ${'Nov 12, 2023 5:43pm UTC (AxisName)'}
        ${'Some non date value'}     | ${'Some non date value (AxisName)'}
        ${12345}                     | ${'12345 (AxisName)'}
        ${true}                      | ${'true (AxisName)'}
        ${''}                        | ${' (AxisName)'}
      `('returns title formatted as "$expected"', ({ value, expected }) => {
        const title = `${value} (AxisName)`;
        const params = {
          seriesData: [
            {
              value: [value],
            },
          ],
        };

        expect(formatVisualizationTooltipTitle(title, params)).toEqual(expected);
      });
    });

    describe('when params object is unexpected structure', () => {
      it('returns title unchanged', () => {
        const title = 'Tooltip title';
        const params = {
          seriesData: [
            {
              value_some_other_property: [123],
            },
          ],
        };

        expect(formatVisualizationTooltipTitle(title, params)).toEqual(title);
      });
    });
  });

  describe('humanizeDisplayUnit', () => {
    it.each`
      unit            | data   | result
      ${'days'}       | ${0.8} | ${'days'}
      ${'days'}       | ${1}   | ${'day'}
      ${'per_day'}    | ${1}   | ${'/day'}
      ${'percent'}    | ${1}   | ${'%'}
      ${'per_second'} | ${1}   | ${'per_second'}
    `('returns $result when data=$data and unit=$unit', ({ unit, data, result }) => {
      expect(humanizeDisplayUnit({ data, unit })).toBe(result);
    });
  });
});
