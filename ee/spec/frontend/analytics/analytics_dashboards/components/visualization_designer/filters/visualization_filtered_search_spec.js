import { GlFilteredSearch } from '@gitlab/ui';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import VisualizationFilteredSearch from 'ee/analytics/analytics_dashboards/components/visualization_designer/filters/visualization_filtered_search.vue';
import { mockMetaData } from 'ee_jest/analytics/analytics_dashboards/mock_data';

describe('ProductAnalyticsVisualizationFilteredSearch', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);

  const createWrapper = () => {
    wrapper = shallowMountExtended(VisualizationFilteredSearch, {
      propsData: {
        query: {},
        availableMeasures: mockMetaData.cubes.at(0).availableMeasures,
        availableDimensions: [mockMetaData.cubes.at(0).dimensions[0]],
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
            options: [
              {
                title: 'Tracked Events Page Urlhosts',
                value: 'TrackedEvents.pageUrlhosts',
              },
            ],
            title: 'Dimension',
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

        describe('and the measure is removed', () => {
          beforeEach(() => {
            wrapper.setProps({ query: { dimensions: ['TrackedEvents.pageUrlhosts'] } });
          });

          it('empties the filtered search component value', () => {
            expect(findFilteredSearch().props('value')).toStrictEqual([]);
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
