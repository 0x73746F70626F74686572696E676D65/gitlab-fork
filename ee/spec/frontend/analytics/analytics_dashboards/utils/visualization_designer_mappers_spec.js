import {
  mapQueryToTokenValues,
  mapTokenValuesToQuery,
} from 'ee/analytics/analytics_dashboards/utils/visualization_designer_mappers';

describe('visualization_designer_mappers', () => {
  describe('mapQueryToTokenValues', () => {
    it('returns an empty array when no query is provided', () => {
      expect(mapQueryToTokenValues({})).toEqual([]);
    });

    it('maps measure values correctly', () => {
      const query = {
        measures: ['Sessions.count'],
      };

      expect(mapQueryToTokenValues(query)).toEqual([
        {
          type: 'measure',
          value: {
            data: 'Sessions.count',
            operator: '=',
          },
        },
      ]);
    });

    it('maps multiple measure values', () => {
      const query = {
        measures: ['Sessions.count', 'TrackedEvents.count'],
      };

      expect(mapQueryToTokenValues(query)).toEqual([
        {
          type: 'measure',
          value: {
            data: 'Sessions.count',
            operator: '=',
          },
        },
        {
          type: 'measure',
          value: {
            data: 'TrackedEvents.count',
            operator: '=',
          },
        },
      ]);
    });
  });

  describe('mapTokenValuesToQuery', () => {
    const availableTokens = [
      {
        type: 'measure',
        options: [{ value: 'Sessions.count' }, { value: 'TrackedEvents.count' }],
      },
    ];

    it('returns the default empty query when no token values are provided', () => {
      expect(mapTokenValuesToQuery([], availableTokens)).toEqual({});
    });

    it('maps valid measure token values to the query', () => {
      const tokenValues = [
        {
          type: 'measure',
          value: {
            data: 'Sessions.count',
            operator: '=',
          },
        },
      ];

      expect(mapTokenValuesToQuery(tokenValues, availableTokens)).toEqual({
        measures: ['Sessions.count'],
      });
    });

    it('ignores invalid measure token values', () => {
      const tokenValues = [
        {
          type: 'measure',
          value: {
            data: 'user typed this',
            operator: '=',
          },
        },
      ];

      expect(mapTokenValuesToQuery(tokenValues, availableTokens)).toEqual({});
    });

    it('maps multiple valid measure token values', () => {
      const tokenValues = [
        {
          type: 'measure',
          value: {
            data: 'Sessions.count',
            operator: '=',
          },
        },
        {
          type: 'measure',
          value: {
            data: 'TrackedEvents.count',
            operator: '=',
          },
        },
      ];

      expect(mapTokenValuesToQuery(tokenValues, availableTokens)).toEqual({
        measures: ['Sessions.count', 'TrackedEvents.count'],
      });
    });
  });
});
