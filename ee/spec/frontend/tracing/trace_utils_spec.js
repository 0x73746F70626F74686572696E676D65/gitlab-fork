import { times } from 'lodash';
import {
  mapTraceToTreeRoot,
  durationNanoToMs,
  formatDurationMs,
  formatTraceDuration,
  assignColorToServices,
  findRootSpan,
} from 'ee/tracing/trace_utils';

describe('trace_utils', () => {
  describe('durationNanoToMs', () => {
    it('converts a duration value from nano to ms', () => {
      expect(durationNanoToMs(1234567)).toBe(1.234567);
    });
  });

  describe('formatDurationMs', () => {
    it.each`
      input      | output              | description
      ${123}     | ${'123ms'}          | ${'format as milliseconds only'}
      ${0.1234}  | ${'0.12ms'}         | ${'format as milliseconds only'}
      ${5000}    | ${'5s'}             | ${'format as seconds only'}
      ${60000}   | ${'1m'}             | ${'format as minutes only'}
      ${3600000} | ${'1h'}             | ${'format as hours only'}
      ${3660}    | ${'3s 660ms'}       | ${'format as seconds and ms'}
      ${121000}  | ${'2m 1s'}          | ${'format as minutes and seconds'}
      ${120100}  | ${'2m 100ms'}       | ${'format as minutes and ms'}
      ${7200020} | ${'2h 20ms'}        | ${'format as hours and ms'}
      ${7260000} | ${'2h 1m'}          | ${'format as hours and minutes'}
      ${3605000} | ${'1h 5s'}          | ${'format as hours and seconds'}
      ${3665000} | ${'1h 1m 5s'}       | ${'format as hours, minutes, and seconds'}
      ${3665123} | ${'1h 1m 5s 123ms'} | ${'format as hours, minutes, seconds, and milliseconds'}
      ${0}       | ${'0ms'}            | ${'handle zero duration'}
      ${-1000}   | ${'0ms'}            | ${'handle negative duration'}
    `('should format $input as $description', ({ input, output }) => {
      expect(formatDurationMs(input)).toBe(output);
    });
  });

  describe('formatTraceDuration', () => {
    it('formats the trace duration nano value', () => {
      expect(formatTraceDuration(5737516022863)).toBe('1h 35m 37s 516ms');
      expect(formatTraceDuration(496896)).toBe('0.50ms');
      expect(formatTraceDuration(9250)).toBe('0.01ms');
    });
  });

  describe('assignColorToService', () => {
    it('should assign the right palette', () => {
      const trace = { duration_nane: 100000, spans: [] };
      trace.spans = times(31).map((i) => ({
        timestamp: '2023-08-07T15:03:32.199806Z',
        span_id: `SPAN-${i}`,
        trace_id: 'TRACE-1',
        service_name: `service-${i}`,
        operation: 'op',
        duration_nano: 100000,
        parent_span_id: '',
      }));

      expect(assignColorToServices(trace)).toEqual({
        'service-0': 'gl-bg-data-viz-blue-500',
        'service-1': 'gl-bg-data-viz-orange-500',
        'service-2': 'gl-bg-data-viz-aqua-500',
        'service-3': 'gl-bg-data-viz-green-500',
        'service-4': 'gl-bg-data-viz-magenta-500',
        'service-5': 'gl-bg-data-viz-blue-600',
        'service-6': 'gl-bg-data-viz-orange-600',
        'service-7': 'gl-bg-data-viz-aqua-600',
        'service-8': 'gl-bg-data-viz-green-600',
        'service-9': 'gl-bg-data-viz-magenta-600',
        'service-10': 'gl-bg-data-viz-blue-700',
        'service-11': 'gl-bg-data-viz-orange-700',
        'service-12': 'gl-bg-data-viz-aqua-700',
        'service-13': 'gl-bg-data-viz-green-700',
        'service-14': 'gl-bg-data-viz-magenta-700',
        'service-15': 'gl-bg-data-viz-blue-800',
        'service-16': 'gl-bg-data-viz-orange-800',
        'service-17': 'gl-bg-data-viz-aqua-800',
        'service-18': 'gl-bg-data-viz-green-800',
        'service-19': 'gl-bg-data-viz-magenta-800',
        'service-20': 'gl-bg-data-viz-blue-900',
        'service-21': 'gl-bg-data-viz-orange-900',
        'service-22': 'gl-bg-data-viz-aqua-900',
        'service-23': 'gl-bg-data-viz-green-900',
        'service-24': 'gl-bg-data-viz-magenta-900',
        'service-25': 'gl-bg-data-viz-blue-950',
        'service-26': 'gl-bg-data-viz-orange-950',
        'service-27': 'gl-bg-data-viz-aqua-950',
        'service-28': 'gl-bg-data-viz-green-950',
        'service-29': 'gl-bg-data-viz-magenta-950',
        // restart pallete
        'service-30': 'gl-bg-data-viz-blue-500',
      });
    });
  });

  describe('findRootSpan', () => {
    const rootSpan = {
      timestamp: '2023-08-07T15:03:53.199871Z',
      span_id: 'SPAN-1',
      trace_id: 'TRACE-1',
      service_name: 'SERVICE-1',
      operation: 'OP-1',
      duration_nano: 123456789,
      parent_span_id: '',
    };
    const nonRootSpan = {
      timestamp: '2023-08-07T15:03:53.199871Z',
      span_id: 'SPAN-2',
      trace_id: 'TRACE-2',
      service_name: 'SERVICE-2',
      operation: 'OP-2',
      duration_nano: 123456789,
      parent_span_id: 'SPAN-1',
    };
    it('returns the root span', () => {
      expect(
        findRootSpan({
          spans: [nonRootSpan, rootSpan],
        }),
      ).toBe(rootSpan);
    });

    it('returns undefined if the root span is missing', () => {
      expect(
        findRootSpan({
          spans: [nonRootSpan],
        }),
      ).toBeUndefined();
    });
  });

  describe('mapTraceToTreeRoot', () => {
    it('should map a trace data to tree data and return the root node', () => {
      const trace = {
        spans: [
          {
            timestamp: '2023-08-07T15:03:53.199871Z',
            span_id: 'SPAN-3',
            trace_id: 'TRACE-1',
            service_name: 'tracegen',
            operation: 'okey-dokey',
            duration_nano: 50027500,
            parent_span_id: 'SPAN-2',
            status_code: 'STATUS_CODE_ERROR',
          },
          {
            timestamp: '2023-08-07T15:03:32.199871Z',
            span_id: 'SPAN-2',
            trace_id: 'TRACE-1',
            service_name: 'tracegen',
            operation: 'okey-dokey',
            duration_nano: 100055000,
            parent_span_id: 'SPAN-1',
          },
          {
            timestamp: '2023-08-07T15:03:53.199871Z',
            span_id: 'SPAN-4',
            trace_id: 'TRACE-1',
            service_name: 'fake-service-2',
            operation: 'okey-dokey',
            duration_nano: 50027500,
            parent_span_id: 'SPAN-2',
          },
          {
            timestamp: '2023-08-07T15:03:32.199806Z',
            span_id: 'SPAN-1',
            trace_id: 'TRACE-1',
            service_name: 'tracegen',
            operation: 'lets-go',
            duration_nano: 100120000,
            parent_span_id: '',
          },
        ],
        duration_nano: 3000000,
      };

      expect(mapTraceToTreeRoot(trace)).toEqual({
        duration_ms: 100.12,
        operation: 'lets-go',
        service: 'tracegen',
        span_id: 'SPAN-1',
        start_ms: 0,
        timestamp: '2023-08-07T15:03:32.199806Z',
        hasError: false,
        children: [
          {
            duration_ms: 100.055,
            operation: 'okey-dokey',
            service: 'tracegen',
            span_id: 'SPAN-2',
            start_ms: 0,
            timestamp: '2023-08-07T15:03:32.199871Z',
            hasError: false,
            children: [
              {
                children: [],
                duration_ms: 50.0275,
                operation: 'okey-dokey',
                service: 'tracegen',
                span_id: 'SPAN-3',
                start_ms: 21000,
                timestamp: '2023-08-07T15:03:53.199871Z',
                hasError: true,
              },
              {
                children: [],
                duration_ms: 50.0275,
                operation: 'okey-dokey',
                service: 'fake-service-2',
                span_id: 'SPAN-4',
                start_ms: 21000,
                timestamp: '2023-08-07T15:03:53.199871Z',
                hasError: false,
              },
            ],
          },
        ],
      });
    });
  });
});
