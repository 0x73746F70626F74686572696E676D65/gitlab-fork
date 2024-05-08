import {
  generateDateRanges,
  generateTableColumns,
  generateSkeletonTableData,
  generateTableRows,
  calculateCodeSuggestionsUsageRate,
} from 'ee/analytics/dashboards/ai_impact/utils';
import { mockTimePeriods } from './mock_data';

describe('AI impact Dashboard utils', () => {
  describe('generateDateRanges', () => {
    it.each`
      date            | description
      ${'07-01-2021'} | ${'on the first of the month'}
      ${'03-31-2021'} | ${'on the last of the month'}
      ${'03-31-2020'} | ${'in a leap year'}
    `('returns the expected date ranges $description', ({ date }) => {
      expect(generateDateRanges(new Date(date))).toMatchSnapshot();
    });
  });

  describe('generateTableColumns', () => {
    it.each`
      date            | description
      ${'07-01-2021'} | ${'on the first of the month'}
      ${'03-31-2021'} | ${'on the last of the month'}
      ${'03-31-2020'} | ${'in a leap year'}
    `('returns the expected table fields $description', ({ date }) => {
      expect(generateTableColumns(new Date(date))).toMatchSnapshot();
    });
  });

  describe('generateSkeletonTableData', () => {
    it('returns the skeleton based on the table fields', () => {
      expect(generateSkeletonTableData()).toMatchSnapshot();
    });
  });

  describe('generateTableRows', () => {
    it('returns the data formatted as a table row', () => {
      expect(generateTableRows(mockTimePeriods)).toMatchSnapshot();
    });
  });

  describe('calculateCodeSuggestionsUsageRate', () => {
    it('returns null when counts are undefined', () => {
      expect(calculateCodeSuggestionsUsageRate()).toBeNull();
    });

    it('returns null when there is no code suggestions usage data', () => {
      expect(
        calculateCodeSuggestionsUsageRate({
          codeSuggestionsContributorsCount: 0,
          codeContributorsCount: 0,
        }),
      ).toBeNull();
    });

    it('returns the code suggestions usage rate as expected', () => {
      expect(
        calculateCodeSuggestionsUsageRate({
          codeSuggestionsContributorsCount: 3,
          codeContributorsCount: 4,
        }),
      ).toEqual(75);
    });
  });
});
