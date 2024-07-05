import { GlSprintf } from '@gitlab/ui';
import ObservabilityUsageBreakdown from 'ee/usage_quotas/observability/components/observability_usage_breakdown.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import { mockData } from './mock_data';

describe('ObservabilityUsageBreakdown', () => {
  let wrapper;

  const mountComponent = (usageData = mockData) => {
    wrapper = shallowMountExtended(ObservabilityUsageBreakdown, {
      propsData: {
        usageData,
      },
      stubs: {
        GlSprintf,
        NumberToHumanSize,
      },
    });
  };

  beforeEach(() => {
    mountComponent();
  });

  const findSectionedStorageUsage = () => wrapper.findByTestId('sectioned-storage-usage');
  const findTotalStorageUsage = () => wrapper.findByTestId('total-storage-usage');
  const findSectionedEventsUsage = () => wrapper.findByTestId('sectioned-events-usage');
  const findTotalEventsUsage = () => wrapper.findByTestId('total-events-usage');

  it('renders a title and subtitle', () => {
    expect(wrapper.find('h4').text()).toBe('Usage breakdown');
    expect(wrapper.find('p').text()).toBe('Includes Logs, Traces and Metrics. Learn more.');
  });

  it('renders the total storage usage', () => {
    expect(findTotalStorageUsage().text()).toBe('57.1 KiB');
  });

  it('renders the sectioned storage usage', () => {
    expect(findSectionedStorageUsage().props('sections')).toEqual([
      { formattedValue: '14.65 KiB', id: 'metrics', label: 'metrics', value: 15000 },
      { formattedValue: '14.65 KiB', id: 'logs', label: 'logs', value: 15000 },
      { formattedValue: '27.81 KiB', id: 'tracing', label: 'tracing', value: 28476 },
    ]);
  });

  it('renders the total events usage', () => {
    expect(findTotalEventsUsage().text()).toBe('132 events');
  });

  it('renders the sectioned events usage', () => {
    expect(findSectionedEventsUsage().props('sections')).toEqual([
      { formattedValue: 40, id: 'metrics', label: 'metrics', value: 40 },
      { formattedValue: 32, id: 'logs', label: 'logs', value: 32 },
      { formattedValue: 60, id: 'tracing', label: 'tracing', value: 60 },
    ]);
  });

  it('does not render events usage if missing', () => {
    mountComponent({ ...mockData, events: {} });

    expect(findTotalEventsUsage().exists()).toBe(false);
    expect(findSectionedEventsUsage().exists()).toBe(false);
  });

  it('does not render storage usage if missing', () => {
    mountComponent({ ...mockData, storage: {} });

    expect(findTotalStorageUsage().exists()).toBe(false);
    expect(findSectionedStorageUsage().exists()).toBe(false);
  });
});
