import { s__, sprintf } from '~/locale';

// See https://design.gitlab.com/data-visualization/color/#categorical-data
const PALETTE = [
  'gl-bg-data-viz-blue-500',
  'gl-bg-data-viz-orange-500',
  'gl-bg-data-viz-aqua-500',
  'gl-bg-data-viz-green-500',
  'gl-bg-data-viz-magenta-500',
  'gl-bg-data-viz-blue-600',
  'gl-bg-data-viz-orange-600',
  'gl-bg-data-viz-aqua-600',
  'gl-bg-data-viz-green-600',
  'gl-bg-data-viz-magenta-600',
  'gl-bg-data-viz-blue-700',
  'gl-bg-data-viz-orange-700',
  'gl-bg-data-viz-aqua-700',
  'gl-bg-data-viz-green-700',
  'gl-bg-data-viz-magenta-700',
  'gl-bg-data-viz-blue-800',
  'gl-bg-data-viz-orange-800',
  'gl-bg-data-viz-aqua-800',
  'gl-bg-data-viz-green-800',
  'gl-bg-data-viz-magenta-800',
  'gl-bg-data-viz-blue-900',
  'gl-bg-data-viz-orange-900',
  'gl-bg-data-viz-aqua-900',
  'gl-bg-data-viz-green-900',
  'gl-bg-data-viz-magenta-900',
  'gl-bg-data-viz-blue-950',
  'gl-bg-data-viz-orange-950',
  'gl-bg-data-viz-aqua-950',
  'gl-bg-data-viz-green-950',
  'gl-bg-data-viz-magenta-950',
];

export function durationNanoToMs(durationNano) {
  return durationNano / 1000000;
}

export function formatDurationMs(durationMs) {
  if (durationMs <= 0) return s__('Tracing|0ms');

  const durationSecs = durationMs / 1000;
  const milliseconds = durationMs % 1000;
  const seconds = Math.floor(durationSecs) % 60;
  const minutes = Math.floor(durationSecs / 60) % 60;
  const hours = Math.floor(durationSecs / 60 / 60);

  const formattedTime = [];
  if (hours > 0) {
    formattedTime.push(sprintf(s__('Tracing|%{h}h'), { h: hours }));
  }
  if (minutes > 0) {
    formattedTime.push(sprintf(s__('Tracing|%{m}m'), { m: minutes }));
  }
  if (seconds > 0) {
    formattedTime.push(sprintf(s__('Tracing|%{s}s'), { s: seconds }));
  }

  if (milliseconds > 0) {
    const ms =
      durationMs >= 1000 || Math.floor(milliseconds) === milliseconds
        ? Math.floor(milliseconds)
        : milliseconds.toFixed(2);
    formattedTime.push(sprintf(s__('Tracing|%{ms}ms'), { ms }));
  }

  return formattedTime.join(' ');
}

export function formatTraceDuration(durationNano) {
  return formatDurationMs(durationNanoToMs(durationNano));
}

export function assignColorToServices(trace) {
  const services = Array.from(new Set(trace.spans.map((s) => s.service_name)));

  const serviceToColor = {};
  services.forEach((s, i) => {
    serviceToColor[s] = PALETTE[i % PALETTE.length];
  });

  return serviceToColor;
}

const timestampToMs = (ts) => new Date(ts).getTime();

export const findRootSpan = (trace) => trace.spans.find((s) => s.parent_span_id === '');

export function mapTraceToTreeRoot(trace) {
  const nodes = {};

  const rootSpan = findRootSpan(trace);
  if (!rootSpan) return undefined;

  const spanToNode = (span) => ({
    start_ms: timestampToMs(span.timestamp) - timestampToMs(rootSpan.timestamp),
    timestamp: span.timestamp,
    span_id: span.span_id,
    operation: span.operation,
    service: span.service_name,
    duration_ms: durationNanoToMs(span.duration_nano),
    children: [],
    hasError: span.status_code === 'STATUS_CODE_ERROR',
  });

  // We need to loop twice here because we don't want to assume that parent nodes appear
  // in the list before children nodes
  trace.spans.forEach((s) => {
    nodes[s.span_id] = spanToNode(s);
  });
  trace.spans.forEach((s) => {
    const node = nodes[s.span_id];
    const parentId = s.parent_span_id;
    if (nodes[parentId]) {
      nodes[parentId].children.push(node);
    }
  });
  return nodes[rootSpan.span_id];
}
