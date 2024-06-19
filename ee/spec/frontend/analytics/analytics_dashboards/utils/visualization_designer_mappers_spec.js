import {
  mapQueryToTokenValues,
  mapTokenValuesToQuery,
} from 'ee/analytics/analytics_dashboards/utils/visualization_designer_mappers';

describe('visualization_designer_mappers', () => {
  describe('mapQueryToTokenValues', () => {
    it('returns an empty array when no query is provided', () => {
      expect(mapQueryToTokenValues({})).toEqual([]);
    });

    describe('with measure', () => {
      it('maps values correctly', () => {
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

      it('maps multiple values correctly', () => {
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

      describe('with dimensions', () => {
        it('maps values correctly', () => {
          const query = {
            measures: ['Sessions.count'],
            dimensions: ['Sessions.osName'],
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
              type: 'dimension',
              value: {
                data: 'Sessions.osName',
                operator: '=',
              },
            },
          ]);
        });

        it('maps multiple values correctly', () => {
          const query = {
            measures: ['Sessions.count'],
            dimensions: ['Sessions.osName', 'Sessions.osVersion'],
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
              type: 'dimension',
              value: {
                data: 'Sessions.osName',
                operator: '=',
              },
            },
            {
              type: 'dimension',
              value: {
                data: 'Sessions.osVersion',
                operator: '=',
              },
            },
          ]);
        });

        describe('with timeDimensions', () => {
          it('maps values correctly', () => {
            const query = {
              measures: ['Sessions.count'],
              dimensions: ['Sessions.osName'],
              timeDimensions: [{ dimension: 'Sessions.startsAt', granularity: 'week' }],
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
                type: 'dimension',
                value: {
                  data: 'Sessions.osName',
                  operator: '=',
                },
              },
              {
                type: 'timeDimension',
                value: {
                  data: `{"dimension":"Sessions.startsAt","granularity":"week"}`,
                  operator: '=',
                },
              },
            ]);
          });
        });
      });
    });
  });

  describe('mapTokenValuesToQuery', () => {
    const availableTokens = [
      {
        type: 'measure',
        options: [{ value: 'Sessions.count' }, { value: 'TrackedEvents.count' }],
      },
      {
        type: 'dimension',
        options: [{ value: 'Sessions.osName' }, { value: 'Sessions.osVersion' }],
      },
      {
        type: 'timeDimension',
        options: [
          { value: '{"dimension":"Sessions.startsAt","granularity":"day"}' },
          { value: '{"dimension":"Sessions.startsAt","granularity":"week"}' },
        ],
      },
    ];
    const validMeasureValue = {
      type: 'measure',
      value: {
        data: 'Sessions.count',
        operator: '=',
      },
    };
    const validDimensionValue = {
      type: 'dimension',
      value: {
        data: 'Sessions.osName',
        operator: '=',
      },
    };

    it('returns the default empty query when no token values are provided', () => {
      expect(mapTokenValuesToQuery([], availableTokens)).toEqual({});
    });

    describe('with measures', () => {
      it('maps valid measure token values to the query', () => {
        const tokenValues = [validMeasureValue];

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
          validMeasureValue,
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

      describe('with dimensions', () => {
        it('maps valid dimension token values to the query', () => {
          const tokenValues = [validMeasureValue, validDimensionValue];

          expect(mapTokenValuesToQuery(tokenValues, availableTokens)).toEqual({
            measures: ['Sessions.count'],
            dimensions: ['Sessions.osName'],
          });
        });

        it('ignores invalid dimension token values', () => {
          const tokenValues = [
            validMeasureValue,
            {
              type: 'dimension',
              value: {
                data: 'user typed this',
                operator: '=',
              },
            },
          ];

          expect(mapTokenValuesToQuery(tokenValues, availableTokens)).toEqual({
            measures: ['Sessions.count'],
          });
        });

        it('maps multiple valid dimension token values', () => {
          const tokenValues = [
            validMeasureValue,
            validDimensionValue,
            {
              type: 'dimension',
              value: {
                data: 'Sessions.osVersion',
                operator: '=',
              },
            },
          ];

          expect(mapTokenValuesToQuery(tokenValues, availableTokens)).toEqual({
            measures: ['Sessions.count'],
            dimensions: ['Sessions.osName', 'Sessions.osVersion'],
          });
        });

        describe('with timeDimensions', () => {
          it('maps valid timeDimension token values to the query', () => {
            const tokenValues = [
              validMeasureValue,
              validDimensionValue,
              {
                type: 'timeDimension',
                value: {
                  data: '{"dimension":"Sessions.startsAt","granularity":"week"}',
                  operator: '=',
                },
              },
            ];

            expect(mapTokenValuesToQuery(tokenValues, availableTokens)).toEqual({
              measures: ['Sessions.count'],
              dimensions: ['Sessions.osName'],
              timeDimensions: [{ dimension: 'Sessions.startsAt', granularity: 'week' }],
            });
          });

          it('ignores invalid timeDimension token values', () => {
            const tokenValues = [
              validMeasureValue,
              validDimensionValue,
              {
                type: 'timeDimension',
                value: {
                  data: 'user typed this',
                  operator: '=',
                },
              },
            ];

            expect(mapTokenValuesToQuery(tokenValues, availableTokens)).toEqual({
              measures: ['Sessions.count'],
              dimensions: ['Sessions.osName'],
            });
          });
        });
      });
    });
  });
});
