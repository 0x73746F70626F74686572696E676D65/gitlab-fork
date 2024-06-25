import { GlLoadingIcon, GlEmptyState, GlSprintf } from '@gitlab/ui';
import MetricsDetails from 'ee/metrics/details/metrics_details.vue';
import { createMockClient } from 'helpers/mock_observability_client';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import * as urlUtility from '~/lib/utils/url_utility';
import MetricsLineChart from 'ee/metrics/details/metrics_line_chart.vue';
import MetricsHeatmap from 'ee/metrics/details/metrics_heatmap.vue';
import FilteredSearch from 'ee/metrics/details/filter_bar/metrics_filtered_search.vue';
import { ingestedAtTimeAgo } from 'ee/metrics/utils';
import { prepareTokens } from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import axios from '~/lib/utils/axios_utils';
import setWindowLocation from 'helpers/set_window_location_helper';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

jest.mock('~/alert');
jest.mock('~/lib/utils/axios_utils');
jest.mock('ee/metrics/utils');

describe('MetricsDetails', () => {
  let wrapper;
  let observabilityClientMock;

  const METRIC_ID = 'test.metric';
  const METRIC_TYPE = 'Sum';
  const METRICS_INDEX_URL = 'https://www.gitlab.com/flightjs/Flight/-/metrics';

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findMetricDetails = () => wrapper.findComponentByTestId('metric-details');

  const findHeader = () => findMetricDetails().find(`[data-testid="metric-header"]`);
  const findHeaderTitle = () => findHeader().find(`[data-testid="metric-title"]`);
  const findHeaderType = () => findHeader().find(`[data-testid="metric-type"]`);
  const findHeaderDescription = () => findHeader().find(`[data-testid="metric-description"]`);
  const findHeaderLastIngested = () => findHeader().find(`[data-testid="metric-last-ingested"]`);
  const findUrlSync = () => wrapper.findComponent(UrlSync);
  const findChart = () => wrapper.find(`[data-testid="metric-chart"]`);
  const findEmptyState = () => findMetricDetails().findComponent(GlEmptyState);
  const findFilteredSearch = () => findMetricDetails().findComponent(FilteredSearch);

  const setFilters = async (attributes, dateRange, groupBy) => {
    findFilteredSearch().vm.$emit('submit', {
      attributes: prepareTokens(attributes),
      dateRange,
      groupBy,
    });
    await waitForPromises();
  };

  const defaultProps = {
    metricId: METRIC_ID,
    metricType: METRIC_TYPE,
    metricsIndexUrl: METRICS_INDEX_URL,
  };

  const showToast = jest.fn();

  const mountComponent = async (props = {}) => {
    wrapper = shallowMountExtended(MetricsDetails, {
      mocks: {
        $toast: {
          show: showToast,
        },
      },
      propsData: {
        ...defaultProps,
        ...props,
        observabilityClient: observabilityClientMock,
      },
      stubs: {
        GlSprintf,
      },
    });
    await waitForPromises();
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  beforeEach(() => {
    jest.spyOn(urlUtility, 'isSafeURL').mockReturnValue(true);

    ingestedAtTimeAgo.mockReturnValue('3 days ago');

    observabilityClientMock = createMockClient();
  });

  it('tracks view_metrics_details_page', () => {
    mountComponent();

    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
    expect(trackEventSpy).toHaveBeenCalledWith('view_metrics_details_page', {}, undefined);
  });

  it('renders the loading indicator while checking if observability is enabled', () => {
    mountComponent();

    expect(findLoadingIcon().exists()).toBe(true);
    expect(findMetricDetails().exists()).toBe(false);
    expect(observabilityClientMock.isObservabilityEnabled).toHaveBeenCalled();
    expect(observabilityClientMock.fetchMetric).not.toHaveBeenCalled();
    expect(observabilityClientMock.fetchMetricSearchMetadata).not.toHaveBeenCalled();
  });

  describe('when observability is enabled', () => {
    const mockMetricData = [
      {
        name: 'container_cpu_usage_seconds_total',
        type: 'Gauge',
        unit: 'gb',
        attributes: {
          beta_kubernetes_io_arch: 'amd64',
          beta_kubernetes_io_instance_type: 'n1-standard-4',
          beta_kubernetes_io_os: 'linux',
          env: 'production',
        },
        values: [
          [1700118610000, 0.25595267476015443],
          [1700118660000, 0.1881374588830907],
          [1700118720000, 0.28915416028993485],
        ],
      },
    ];

    const mockSearchMetadata = {
      name: 'cpu_seconds_total',
      type: 'sum',
      description: 'System disk operations',
      last_ingested_at: 1705374438711900000,
      attribute_keys: ['host.name', 'host.dc', 'host.type'],
      supported_aggregations: ['1m', '1h'],
      supported_functions: ['min', 'max', 'avg', 'sum', 'count'],
      default_group_by_attributes: ['host.name'],
      default_group_by_function: ['avg'],
    };

    beforeEach(async () => {
      observabilityClientMock.isObservabilityEnabled.mockResolvedValue(true);
      observabilityClientMock.fetchMetric.mockResolvedValue(mockMetricData);
      observabilityClientMock.fetchMetricSearchMetadata.mockResolvedValue(mockSearchMetadata);

      await mountComponent();
    });

    it('renders the loading indicator while fetching data', () => {
      mountComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findMetricDetails().exists()).toBe(false);
    });

    it('fetches data', () => {
      expect(observabilityClientMock.isObservabilityEnabled).toHaveBeenCalled();
      expect(observabilityClientMock.fetchMetric).toHaveBeenCalledWith(
        METRIC_ID,
        METRIC_TYPE,
        expect.any(Object),
      );
      expect(observabilityClientMock.fetchMetricSearchMetadata).toHaveBeenCalledWith(
        METRIC_ID,
        METRIC_TYPE,
      );
    });

    describe('when metric type is an histogram', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchMetric.mockClear();

        await mountComponent({ metricType: 'histogram' });
      });

      it('fetches data with heatmap visual', () => {
        expect(observabilityClientMock.fetchMetric).toHaveBeenCalledWith(METRIC_ID, 'histogram', {
          abortController: expect.any(AbortController),
          filters: expect.any(Object),
          visual: 'heatmap',
        });
      });

      it('renders the heatmap chart', () => {
        expect(findMetricDetails().findComponent(MetricsLineChart).exists()).toBe(false);
        expect(findMetricDetails().findComponent(MetricsHeatmap).exists()).toBe(true);
      });
    });

    it('renders the metrics details', () => {
      expect(observabilityClientMock.fetchMetric).toHaveBeenCalledWith(METRIC_ID, METRIC_TYPE, {
        abortController: expect.any(AbortController),
        filters: expect.any(Object),
      });
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findMetricDetails().exists()).toBe(true);
    });

    describe('filtered search', () => {
      beforeEach(async () => {
        setWindowLocation(
          '?type=Sum&foo.bar[]=eq-val' +
            '&not%5Bfoo.bar%5D[]=not-eq-val' +
            '&like%5Bfoo.baz%5D[]=like-val' +
            '&not_like%5Bfoo.baz%5D[]=not-like-val' +
            '&group_by_fn=avg' +
            '&group_by_attrs[]=foo' +
            '&group_by_attrs[]=bar' +
            '&date_range=custom' +
            '&date_start=2020-01-01T00%3A00%3A00.000Z' +
            '&date_end=2020-01-02T00%3A00%3A00.000Z',
        );
        observabilityClientMock.fetchMetric.mockClear();
        observabilityClientMock.fetchMetricSearchMetadata.mockClear();
        await mountComponent();
      });

      it('renders the FilteredSearch component', () => {
        const filteredSearch = findFilteredSearch();
        expect(filteredSearch.exists()).toBe(true);
        expect(filteredSearch.props('searchMetadata')).toBe(mockSearchMetadata);
      });

      it('does not render the filtered search component if fetching metadata fails', async () => {
        observabilityClientMock.fetchMetricSearchMetadata.mockRejectedValueOnce('error');
        await mountComponent();
        expect(findFilteredSearch().exists()).toBe(false);
      });

      it('fetches metrics with filters', () => {
        expect(observabilityClientMock.fetchMetric).toHaveBeenCalledWith(METRIC_ID, METRIC_TYPE, {
          abortController: expect.any(AbortController),
          filters: {
            attributes: {
              'foo.bar': [
                { operator: '=', value: 'eq-val' },
                { operator: '!=', value: 'not-eq-val' },
              ],
              'foo.baz': [
                { operator: '=~', value: 'like-val' },
                { operator: '!~', value: 'not-like-val' },
              ],
            },
            groupBy: {
              func: 'avg',
              attributes: ['foo', 'bar'],
            },
            dateRange: {
              value: 'custom',
              startDate: new Date('2020-01-01'),
              endDate: new Date('2020-01-02'),
            },
          },
        });
      });

      it('initialises filtered-search props with values from query', () => {
        expect(findFilteredSearch().props('dateRangeFilter')).toEqual({
          endDate: new Date('2020-01-02T00:00:00.000Z'),
          startDate: new Date('2020-01-01T00:00:00.000Z'),
          value: 'custom',
        });

        expect(findFilteredSearch().props('groupByFilter')).toEqual({
          attributes: ['foo', 'bar'],
          func: 'avg',
        });

        expect(findFilteredSearch().props('attributeFilters')).toEqual(
          prepareTokens({
            'foo.bar': [
              { operator: '=', value: 'eq-val' },
              { operator: '!=', value: 'not-eq-val' },
            ],
            'foo.baz': [
              { operator: '=~', value: 'like-val' },
              { operator: '!~', value: 'not-like-val' },
            ],
          }),
        );
      });

      it('renders UrlSync and sets query prop', () => {
        expect(findUrlSync().props('query')).toEqual({
          'foo.bar': ['eq-val'],
          'not[foo.bar]': ['not-eq-val'],
          'like[foo.bar]': null,
          'not_like[foo.bar]': null,
          'foo.baz': null,
          'not[foo.baz]': null,
          'like[foo.baz]': ['like-val'],
          'not_like[foo.baz]': ['not-like-val'],
          group_by_fn: 'avg',
          group_by_attrs: ['foo', 'bar'],
          date_range: 'custom',
          date_end: '2020-01-02T00:00:00.000Z',
          date_start: '2020-01-01T00:00:00.000Z',
        });
      });

      it('sets the default date range if not specified', async () => {
        setWindowLocation('?type=Sum');

        await mountComponent();

        expect(findFilteredSearch().props('dateRangeFilter')).toEqual({
          value: '1h',
        });
        expect(observabilityClientMock.fetchMetric).toHaveBeenCalledWith(METRIC_ID, METRIC_TYPE, {
          abortController: expect.any(AbortController),
          filters: {
            attributes: {},
            groupBy: {},
            dateRange: {
              value: '1h',
            },
          },
        });
        expect(findUrlSync().props('query')).toEqual({
          date_range: '1h',
        });
      });

      describe('on search cancel', () => {
        let abortSpy;
        beforeEach(() => {
          abortSpy = jest.spyOn(AbortController.prototype, 'abort');
        });
        it('does not abort the api call when canceled if a search was not initiated', () => {
          findFilteredSearch().vm.$emit('cancel');

          expect(abortSpy).not.toHaveBeenCalled();
        });

        it('aborts the api call when canceled if a search was initiated', () => {
          findFilteredSearch().vm.$emit('submit', {
            attributes: [],
          });

          expect(abortSpy).not.toHaveBeenCalled();

          findFilteredSearch().vm.$emit('cancel');

          expect(abortSpy).toHaveBeenCalled();
        });

        describe('when cancelled', () => {
          beforeEach(async () => {
            axios.isCancel = jest.fn().mockReturnValueOnce(true);
            observabilityClientMock.fetchMetric.mockRejectedValueOnce('cancelled');
            findFilteredSearch().vm.$emit('submit', {
              attributes: [],
            });
            await waitForPromises();
          });

          it('renders a toast and message', () => {
            expect(showToast).toHaveBeenCalledWith('Metrics search has been cancelled.', {
              variant: 'danger',
            });
          });

          it('sets cancelled prop on the chart component', () => {
            expect(findChart().props('cancelled')).toBe(true);
          });

          it('reset cancelled prop after issuing a new search', async () => {
            observabilityClientMock.fetchMetric.mockResolvedValue(mockMetricData);
            findFilteredSearch().vm.$emit('submit', {
              attributes: [],
            });
            await waitForPromises();

            expect(findChart().props('cancelled')).toBe(false);
          });
        });
      });

      describe('while searching', () => {
        beforeEach(() => {
          observabilityClientMock.fetchMetric.mockReturnValue(new Promise(() => {}));

          findFilteredSearch().vm.$emit('submit', {
            attributes: [],
          });
        });

        it('does not show the loading icon', () => {
          expect(findLoadingIcon().exists()).toBe(false);
        });

        it('sets the loading prop on the filtered-search component', () => {
          expect(findFilteredSearch().props('loading')).toBe(true);
        });

        it('sets the loading prop on the chart component', () => {
          expect(findChart().props('loading')).toBe(true);
        });
      });

      it('renders the loading indicator while fetching new data with currently empty data', async () => {
        observabilityClientMock.fetchMetric.mockResolvedValue([]);
        await mountComponent();

        await findFilteredSearch().vm.$emit('submit', {
          attributes: [],
        });

        expect(findLoadingIcon().exists()).toBe(true);
      });

      describe('on search submit', () => {
        const updatedMetricData = [
          {
            name: 'container_cpu_usage_seconds_total',
            type: 'Gauge',
            unit: 'gb',
            attributes: {
              beta_kubernetes_io_arch: 'amd64',
            },
            values: [[1700118610000, 0.25595267476015443]],
          },
        ];
        beforeEach(async () => {
          observabilityClientMock.fetchMetric.mockResolvedValue(updatedMetricData);
          await setFilters(
            {
              'key.one': [{ operator: '=', value: 'test' }],
            },
            {
              endDate: new Date('2020-07-06T00:00:00.000Z'),
              startDarte: new Date('2020-07-05T23:00:00.000Z'),
              value: '30d',
            },
            {
              func: 'sum',
              attributes: ['attr_1', 'attr_2'],
            },
          );
        });

        it('fetches traces with updated filters', () => {
          expect(observabilityClientMock.fetchMetric).toHaveBeenLastCalledWith(
            METRIC_ID,
            METRIC_TYPE,
            {
              abortController: expect.any(AbortController),
              filters: {
                attributes: {
                  'key.one': [{ operator: '=', value: 'test' }],
                },
                dateRange: {
                  endDate: new Date('2020-07-06T00:00:00.000Z'),
                  startDarte: new Date('2020-07-05T23:00:00.000Z'),
                  value: '30d',
                },
                groupBy: {
                  func: 'sum',
                  attributes: ['attr_1', 'attr_2'],
                },
              },
            },
          );
        });

        it('updates the query on search submit', () => {
          expect(findUrlSync().props('query')).toEqual({
            'key.one': ['test'],
            'not[key.one]': null,
            'like[key.one]': null,
            'not_like[key.one]': null,
            group_by_fn: 'sum',
            group_by_attrs: ['attr_1', 'attr_2'],
            date_range: '30d',
          });
        });

        it('updates FilteredSearch props', () => {
          expect(findFilteredSearch().props('dateRangeFilter')).toEqual({
            endDate: new Date('2020-07-06T00:00:00.000Z'),
            startDarte: new Date('2020-07-05T23:00:00.000Z'),
            value: '30d',
          });
          expect(findFilteredSearch().props('attributeFilters')).toEqual(
            prepareTokens({
              'key.one': [{ operator: '=', value: 'test' }],
            }),
          );
          expect(findFilteredSearch().props('groupByFilter')).toEqual({
            func: 'sum',
            attributes: ['attr_1', 'attr_2'],
          });
        });

        it('updates the details chart data', () => {
          expect(findChart().props('metricData')).toEqual(updatedMetricData);
        });
      });
    });

    it('renders the details chart', () => {
      const chart = findChart();
      expect(chart.exists()).toBe(true);
      expect(chart.props('metricData')).toEqual(mockMetricData);
      expect(chart.props('cancelled')).toBe(false);
      expect(chart.props('loading')).toBe(false);
    });

    it('renders a line chart by default', () => {
      expect(findMetricDetails().findComponent(MetricsLineChart).exists()).toBe(true);
      expect(findMetricDetails().findComponent(MetricsHeatmap).exists()).toBe(false);
    });

    it('renders the details header', () => {
      expect(findHeader().exists()).toBe(true);
      expect(findHeaderTitle().text()).toBe(METRIC_ID);
      expect(findHeaderType().text()).toBe(`Type:\u00a0${METRIC_TYPE}`);
      expect(findHeaderDescription().text()).toBe('System disk operations');
      expect(findHeaderLastIngested().text()).toBe('Last ingested:\u00a03 days ago');
      expect(ingestedAtTimeAgo).toHaveBeenCalledWith(mockSearchMetadata.last_ingested_at);
    });

    describe('with no data', () => {
      beforeEach(async () => {
        observabilityClientMock.fetchMetric.mockResolvedValue([]);

        await mountComponent();
      });

      it('renders the header', () => {
        expect(findHeaderTitle().text()).toBe(METRIC_ID);
        expect(findHeaderType().text()).toBe(`Type:\u00a0${METRIC_TYPE}`);
        expect(findHeaderLastIngested().text()).toBe('Last ingested:\u00a03 days ago');
        expect(findHeaderDescription().text()).toBe('System disk operations');
      });

      it('renders the empty state, with description for selected time range', () => {
        expect(findEmptyState().exists()).toBe(true);
        expect(findEmptyState().text()).toMatchInterpolatedText(
          'No data found for the selected time range (last 1 hour) Last ingested: 3 days ago',
        );
      });

      it('renders the empty state, with no description for the selected time range', async () => {
        await setFilters({}, { value: 'custom' });
        expect(findEmptyState().exists()).toBe(true);
        expect(findEmptyState().text()).toMatchInterpolatedText(
          'No data found for the selected time range Last ingested: 3 days ago',
        );
      });
    });
  });

  describe('when observability is not enabled', () => {
    beforeEach(async () => {
      observabilityClientMock.isObservabilityEnabled.mockResolvedValue(false);
      jest.spyOn(urlUtility, 'visitUrl').mockReturnValue({});
      await mountComponent();
    });

    it('redirects to metricsIndexUrl', () => {
      expect(urlUtility.visitUrl).toHaveBeenCalledWith(defaultProps.metricsIndexUrl);
    });

    it('does not fetch data', () => {
      expect(observabilityClientMock.isObservabilityEnabled).toHaveBeenCalled();
      expect(observabilityClientMock.fetchMetric).not.toHaveBeenCalled();
      expect(observabilityClientMock.fetchMetricSearchMetadata).not.toHaveBeenCalled();
    });
  });

  describe('error handling', () => {
    beforeEach(() => {
      observabilityClientMock.isObservabilityEnabled.mockResolvedValue(true);
      observabilityClientMock.fetchMetric.mockResolvedValue([]);
      observabilityClientMock.fetchMetricSearchMetadata.mockResolvedValue({});
    });

    describe.each([
      ['isObservabilityEnabled', () => observabilityClientMock.isObservabilityEnabled],
      ['fetchMetricSearchMetadata', () => observabilityClientMock.fetchMetricSearchMetadata],
      ['fetchMetric', () => observabilityClientMock.fetchMetric],
    ])('when %s fails', (_, mockFn) => {
      beforeEach(async () => {
        mockFn().mockRejectedValue('error');
        await mountComponent();
      });
      it('renders an alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Error: Failed to load metrics details. Try reloading the page.',
        });
      });

      it('only renders the empty state and header', () => {
        expect(findMetricDetails().exists()).toBe(true);
        expect(findEmptyState().exists()).toBe(true);
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findHeader().exists()).toBe(true);
        expect(findChart().exists()).toBe(false);
      });
    });

    it('renders an alert if metricId is missing', async () => {
      await mountComponent({ metricId: undefined });

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Error: Failed to load metrics details. Try reloading the page.',
      });
    });

    it('renders an alert if metricType is missing', async () => {
      await mountComponent({ metricType: undefined });

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Error: Failed to load metrics details. Try reloading the page.',
      });
    });
  });
});
