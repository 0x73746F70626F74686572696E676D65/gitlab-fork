import { assignColorToServices, durationNanoToMs } from 'ee/tracing/trace_utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TracingChart from 'ee/tracing/details/tracing_chart.vue';
import TracingDetailsSpansChart from 'ee/tracing/details/tracing_spans_chart.vue';

jest.mock('ee/tracing/trace_utils');

describe('TracingChart', () => {
  let wrapper;

  const mockTrace = {
    timestamp: '2023-08-07T15:03:32.199806Z',
    trace_id: 'dabb7ae1-2501-8e57-18e1-30ab21a9ab19',
    service_name: 'tracegen',
    operation: 'lets-go',
    statusCode: 'STATUS_CODE_UNSET',
    duration_nano: 100120000,
    spans: [
      {
        timestamp: '2023-08-07T15:03:32.199806Z',
        span_id: 'SPAN-1',
        trace_id: 'dabb7ae1-2501-8e57-18e1-30ab21a9ab19',
        service_name: 'tracegen',
        operation: 'lets-go',
        duration_nano: 100120000,
        parent_span_id: '',
        statusCode: 'STATUS_CODE_UNSET',
      },
      {
        timestamp: '2023-08-07T15:03:32.199806Z',
        span_id: 'SPAN-2',
        trace_id: 'dabb7ae1-2501-8e57-18e1-30ab21a9ab19',
        service_name: 'tracegen',
        operation: 'lets-go',
        duration_nano: 100120000,
        parent_span_id: '',
        statusCode: 'STATUS_CODE_UNSET',
      },
    ],
  };

  const mountComponent = () => {
    wrapper = shallowMountExtended(TracingChart, {
      propsData: {
        trace: mockTrace,
        selectedSpanId: 'foo',
        spanTrees: [mockTrace.spans[0], mockTrace.spans[1]],
      },
    });
  };

  beforeEach(() => {
    assignColorToServices.mockReturnValue({ tracegen: 'red' });
    durationNanoToMs.mockReturnValue(100);

    mountComponent();
  });

  const getTracingDetailsSpansCharts = () => wrapper.findAllComponents(TracingDetailsSpansChart);

  it('renders a TracingDetailsSpansChart for each root', () => {
    const charts = getTracingDetailsSpansCharts();
    expect(charts.length).toBe(2);
    expect(charts.at(0).props('spans')).toEqual([mockTrace.spans[0]]);
    expect(charts.at(1).props('spans')).toEqual([mockTrace.spans[1]]);
  });

  it('passes the correct props to the TracingDetailsSpansChart component', () => {
    const tracingDetailsSpansChart = getTracingDetailsSpansCharts().at(0);

    expect(tracingDetailsSpansChart.props('traceDurationMs')).toBe(100);
    expect(tracingDetailsSpansChart.props('serviceToColor')).toEqual({ tracegen: 'red' });
    expect(tracingDetailsSpansChart.props('selectedSpanId')).toEqual('foo');
  });

  it('emits span-selected upon span selection', () => {
    getTracingDetailsSpansCharts().at(0).vm.$emit('span-selected', { spanId: 'foo' });

    expect(wrapper.emitted('span-selected')).toStrictEqual([[{ spanId: 'foo' }]]);
  });
});
