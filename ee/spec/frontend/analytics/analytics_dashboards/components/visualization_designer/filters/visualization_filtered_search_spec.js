import { nextTick } from 'vue';
import { GlFilteredSearch } from '@gitlab/ui';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import VisualizationFilteredSearch from 'ee/analytics/analytics_dashboards/components/visualization_designer/filters/visualization_filtered_search.vue';
import { mockQueryBuilderValues } from 'ee_jest/analytics/analytics_dashboards/mock_data';

describe('ProductAnalyticsVisualizationFilteredSearch', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);

  const createWrapper = () => {
    wrapper = shallowMountExtended(VisualizationFilteredSearch, {
      propsData: {
        query: {},
        availableMeasures: mockQueryBuilderValues.availableMeasures,
        availableDimensions: mockQueryBuilderValues.availableDimensions,
        availableTimeDimensions: mockQueryBuilderValues.availableTimeDimensions,
      },
    });
  };

  describe('when mounted', () => {
    beforeEach(() => createWrapper());

    it('renders the filtered search component', () => {
      const filteredSearch = findFilteredSearch();

      expect(filteredSearch.props('availableTokens')).toStrictEqual([
        expect.objectContaining({
          operators: expect.any(Array),
          options: [
            {
              title: 'Tracked Events Count',
              value: 'TrackedEvents.count',
            },
          ],
          title: 'Measure',
        }),
      ]);
      expect(filteredSearch.props('value')).toEqual([]);
      expect(filteredSearch.props('placeholder')).toEqual('Start by choosing a measure');
      expect(filteredSearch.props('clearButtonTitle')).toEqual('Clear');
    });

    describe('when the query contains a measure', () => {
      beforeEach(() => {
        wrapper.setProps({ query: { measures: ['TrackedEvents.count'] } });
      });

      it('updates the filtered search component value', () => {
        expect(findFilteredSearch().props('value')).toStrictEqual([
          {
            type: 'measure',
            value: {
              data: 'TrackedEvents.count',
              operator: '=',
            },
          },
        ]);
      });

      it('adds dimension tokens to the availableTokens', () => {
        expect(findFilteredSearch().props('availableTokens')).toContainEqual(
          expect.objectContaining({
            operators: expect.any(Array),
            options: expect.arrayContaining([
              {
                title: 'Tracked Events Page Urlhosts',
                value: 'TrackedEvents.pageUrlhosts',
              },
            ]),
            title: 'Dimension',
          }),
        );
      });

      it('adds timeDimension token to the availableTokens', () => {
        expect(findFilteredSearch().props('availableTokens')).toContainEqual(
          expect.objectContaining({
            operators: expect.any(Array),
            options: expect.arrayContaining([
              {
                title: 'Seconds',
                value: '{"dimension":"TrackedEvents.derivedTstamp","granularity":"seconds"}',
              },
            ]),
            type: 'timeDimension',
            title: 'Group by',
          }),
        );
      });

      describe('and a dimension is added', () => {
        beforeEach(() => {
          wrapper.setProps({
            query: {
              measures: ['TrackedEvents.count'],
              dimensions: ['TrackedEvents.pageUrlhosts'],
            },
          });
        });

        it('updates the filtered search component value with the dimension', () => {
          expect(findFilteredSearch().props('value')).toContainEqual({
            type: 'dimension',
            value: {
              data: 'TrackedEvents.pageUrlhosts',
              operator: '=',
            },
          });
        });

        describe('and the dimension is removed', () => {
          beforeEach(() => {
            wrapper.setProps({ query: { measures: ['TrackedEvents.count'] } });
          });

          it('retains the measure token', () => {
            expect(findFilteredSearch().props('value')).toStrictEqual([
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

        describe('and the measure is removed', () => {
          beforeEach(() => {
            wrapper.setProps({ query: { dimensions: ['TrackedEvents.pageUrlhosts'] } });
          });

          it('empties the filtered search component value', () => {
            expect(findFilteredSearch().props('value')).toStrictEqual([]);
          });
        });
      });

      describe('with the Sessions cube', () => {
        beforeEach(() => {
          wrapper.setProps({
            query: {
              measures: ['Sessions.count'],
            },
          });
        });

        it('selects the expected timeDimension token for availableTokens', () => {
          const availableTokens = findFilteredSearch().props('availableTokens');
          expect(availableTokens).toContainEqual(
            expect.objectContaining({
              operators: expect.any(Array),
              options: expect.arrayContaining([
                {
                  title: 'Seconds',
                  value: '{"dimension":"Sessions.startAt","granularity":"seconds"}',
                },
              ]),
              type: 'timeDimension',
              title: 'Group by',
            }),
          );

          expect(availableTokens).not.toContainEqual(
            expect.objectContaining({
              operators: expect.any(Array),
              options: expect.arrayContaining([
                {
                  title: 'Seconds',
                  value: '{"dimension":"Sessions.endAt","granularity":"seconds"}',
                },
              ]),
              type: 'timeDimension',
              title: 'Group by',
            }),
          );
        });
      });

      describe('and a timeDimension is added', () => {
        beforeEach(() => {
          wrapper.setProps({
            query: {
              measures: ['TrackedEvents.count'],
              timeDimensions: [
                { dimension: 'TrackedEvents.derivedTstamp', granularity: 'seconds' },
              ],
            },
          });
        });

        it('updates the filtered search component value with the timeDimension', () => {
          expect(findFilteredSearch().props('value')).toContainEqual({
            type: 'timeDimension',
            value: {
              data: '{"dimension":"TrackedEvents.derivedTstamp","granularity":"seconds"}',
              operator: '=',
            },
          });
        });

        describe('and the measure is removed', () => {
          beforeEach(() => {
            wrapper.setProps({
              query: {
                timeDimensions: [
                  { dimension: 'TrackedEvents.derivedTstamp', granularity: 'seconds' },
                ],
              },
            });
          });

          it('empties the filtered search component value', () => {
            expect(findFilteredSearch().props('value')).toStrictEqual([]);
          });
        });

        describe('and the timeDimension is removed', () => {
          beforeEach(() => {
            wrapper.setProps({
              query: {
                measures: ['TrackedEvents.count'],
                dimensions: ['TrackedEvents.pageUrlhosts'],
              },
            });
          });

          it('retains the measure and dimension token', () => {
            expect(findFilteredSearch().props('value')).toStrictEqual([
              {
                type: 'measure',
                value: {
                  data: 'TrackedEvents.count',
                  operator: '=',
                },
              },
              {
                type: 'dimension',
                value: {
                  data: 'TrackedEvents.pageUrlhosts',
                  operator: '=',
                },
              },
            ]);
          });
        });
      });

      describe('and a custom event name filter is added', () => {
        const customEventQuery = {
          measures: ['TrackedEvents.count'],
          filters: [
            {
              member: 'TrackedEvents.customEventName',
              operator: 'equals',
              values: ['custom_event'],
            },
          ],
        };

        beforeEach(() => {
          wrapper.setProps({
            query: { ...customEventQuery },
          });
        });

        it('updates the filtered search component value with the custom event names', () => {
          expect(findFilteredSearch().props('value')).toContainEqual({
            type: 'customEventName',
            value: {
              data: 'custom_event',
              operator: '=',
            },
          });
        });

        describe('and the measure is changed from tracked events', () => {
          beforeEach(() => {
            wrapper.setProps({
              query: {
                ...customEventQuery,
                measures: ['Sessions.count'],
              },
            });
          });

          it('removes the custom event name token from the filtered search component value', () => {
            expect(findFilteredSearch().props('value')).toStrictEqual([
              {
                type: 'measure',
                value: {
                  data: 'Sessions.count',
                  operator: '=',
                },
              },
            ]);
          });
        });

        describe('and the measure is removed', () => {
          beforeEach(() => {
            wrapper.setProps({
              query: {
                ...customEventQuery,
                measures: [],
              },
            });
          });

          it('empties the filtered search component value', () => {
            expect(findFilteredSearch().props('value')).toStrictEqual([]);
          });
        });
      });

      describe('custom event name filter supported measures', () => {
        it.each`
          measure                              | supported
          ${'TrackedEvents.count'}             | ${true}
          ${'TrackedEvents.uniqueUsersCount'}  | ${true}
          ${'TrackedEvents.linkClicksCount'}   | ${false}
          ${'Sessions.count'}                  | ${false}
          ${'ReturningUsers.allSessionsCount'} | ${false}
        `('when measure is $measure, support is $supported', async ({ measure, supported }) => {
          wrapper.setProps({ query: { measures: [measure] } });

          await nextTick();

          const availableTokenTitles = findFilteredSearch()
            .props('availableTokens')
            .map(({ title }) => title);

          if (supported) {
            expect(availableTokenTitles).toContain('Custom event name');
          } else {
            expect(availableTokenTitles).not.toContain('Custom event name');
          }
        });
      });
    });

    describe.each(['input', 'submit'])('when filtered-search emits "%s"', (event) => {
      beforeEach(() => {
        findFilteredSearch().vm.$emit(event, [
          {
            type: 'measure',
            value: {
              data: 'TrackedEvents.count',
              operator: '=',
            },
          },
        ]);
      });

      it(`emits "${event}" event`, () => {
        expect(wrapper.emitted(event)).toHaveLength(1);
      });

      it(`maps token to query`, () => {
        const [emittedQuery] = wrapper.emitted(event).at(0);

        expect(emittedQuery.measures).toContain('TrackedEvents.count');
      });

      it('includes default query properties', () => {
        const [emittedQuery] = wrapper.emitted(event).at(0);

        expect(emittedQuery.limit).toEqual(100);
      });
    });
  });
});
