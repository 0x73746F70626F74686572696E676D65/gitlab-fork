import * as utils from 'ee/analytics/analytics_dashboards/utils';
import {
  TEST_VISUALIZATION,
  mockQueryBuilderValues,
} from 'ee_jest/analytics/analytics_dashboards/mock_data';

describe('Analytics dashboard utils', () => {
  describe('#createNewVisualizationPanel', () => {
    it('returns the expected object', () => {
      const visualization = TEST_VISUALIZATION();
      expect(utils.createNewVisualizationPanel(visualization)).toMatchObject({
        visualization: {
          ...visualization,
          errors: null,
        },
        title: 'Test visualization',
        gridAttributes: {
          width: 4,
          height: 3,
        },
        options: {},
      });
    });
  });

  describe('getMetricSchema', () => {
    it.each`
      metric                        | expected
      ${'Sessions.count'}           | ${'Sessions'}
      ${'TrackedEvents.count'}      | ${'TrackedEvents'}
      ${'ReturningUsers.something'} | ${'ReturningUsers'}
    `('returns "$expected" for metric "$metric"', ({ metric, expected }) => {
      expect(utils.getMetricSchema(metric)).toBe(expected);
    });

    it.each([undefined, null])('returns undefined for "%s"', (value) => {
      expect(utils.getMetricSchema(value)).toBeUndefined();
    });
  });

  describe('getDimensionsForSchema', () => {
    it('returns an empty array when no schema is provided', () => {
      expect(
        utils.getDimensionsForSchema(null, mockQueryBuilderValues.availableDimensions),
      ).toEqual([]);
    });

    it('returns an empty array when the schema does not match any dimensions', () => {
      expect(
        utils.getDimensionsForSchema('InvalidSchema', mockQueryBuilderValues.availableDimensions),
      ).toEqual([]);
    });

    it('returns the expected dimensions for a schema', () => {
      expect(
        utils
          .getDimensionsForSchema('TrackedEvents', mockQueryBuilderValues.availableDimensions)
          .map(({ name }) => name),
      ).toEqual([
        'TrackedEvents.pageUrlhosts',
        'TrackedEvents.pageUrlpath',
        'TrackedEvents.event',
        'TrackedEvents.pageTitle',
        'TrackedEvents.osFamily',
        'TrackedEvents.osName',
        'TrackedEvents.osVersion',
        'TrackedEvents.osVersionMajor',
        'TrackedEvents.agentName',
        'TrackedEvents.agentVersion',
        'TrackedEvents.pageReferrer',
        'TrackedEvents.pageUrl',
        'TrackedEvents.useragent',
        'TrackedEvents.userId',
        'TrackedEvents.derivedTstamp',
        'TrackedEvents.browserLanguage',
        'TrackedEvents.documentLanguage',
        'TrackedEvents.viewportSize',
      ]);
    });
  });

  describe('getTimeDimensionForSchema', () => {
    it('returns null when no schema is provided', () => {
      expect(
        utils.getTimeDimensionForSchema(null, mockQueryBuilderValues.availableTimeDimensions),
      ).toBeNull();
    });

    it('returns null when the schema does not match any time dimensions', () => {
      expect(
        utils.getTimeDimensionForSchema(
          'InvalidSchema',
          mockQueryBuilderValues.availableTimeDimensions,
        ),
      ).toBeNull();
    });

    it('returns the expected time dimension for a schema with a single time dimension', () => {
      expect(
        utils.getTimeDimensionForSchema(
          'TrackedEvents',
          mockQueryBuilderValues.availableTimeDimensions,
        ),
      ).toEqual({
        name: 'TrackedEvents.derivedTstamp',
        title: 'Tracked Events Derived Tstamp',
        type: 'time',
        shortTitle: 'Derived Tstamp',
        suggestFilterValues: true,
        isVisible: true,
        public: true,
        primaryKey: false,
      });
    });

    it('returns null for a schema with multiple time dimensions', () => {
      expect(
        utils.getTimeDimensionForSchema('UnknownSchema', [
          { name: 'UnknownSchema.createdAt' },
          { name: 'UnknownSchema.updatedAt' },
        ]),
      ).toBeNull();
    });

    it('returns the "Sessions.startAt" time dimension for the "Sessions" schema', () => {
      expect(
        utils.getTimeDimensionForSchema('Sessions', mockQueryBuilderValues.availableTimeDimensions),
      ).toEqual({
        name: 'Sessions.startAt',
        title: 'Sessions Start at',
        type: 'time',
        shortTitle: 'Start at',
        suggestFilterValues: true,
        isVisible: true,
        public: true,
        primaryKey: false,
      });
    });
  });
});
