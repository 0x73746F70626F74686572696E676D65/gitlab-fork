const COLORS_MAP = {
  trace: '#a4a3a8',
  debug: '#a4a3a8',
  info: '#428fdc',
  warn: '#e9be74',
  error: '#dd2b0e',
  fatal: '#dd2b0e',
};

// See OTEL spec: https://opentelemetry.io/docs/specs/otel/logs/data-model/#displaying-severity
const severityConfig = [
  null, // severity-0 is not used
  { name: 'trace', color: COLORS_MAP.trace },
  { name: 'trace2', color: COLORS_MAP.trace },
  { name: 'trace3', color: COLORS_MAP.trace },
  { name: 'trace4', color: COLORS_MAP.trace },
  { name: 'debug', color: COLORS_MAP.debug },
  { name: 'debug2', color: COLORS_MAP.debug },
  { name: 'debug3', color: COLORS_MAP.debug },
  { name: 'debug4', color: COLORS_MAP.debug },
  { name: 'info', color: COLORS_MAP.info },
  { name: 'info2', color: COLORS_MAP.info },
  { name: 'info3', color: COLORS_MAP.info },
  { name: 'info4', color: COLORS_MAP.info },
  { name: 'warn', color: COLORS_MAP.warn },
  { name: 'warn2', color: COLORS_MAP.warn },
  { name: 'warn3', color: COLORS_MAP.warn },
  { name: 'warn4', color: COLORS_MAP.warn },
  { name: 'error', color: COLORS_MAP.error },
  { name: 'error2', color: COLORS_MAP.error },
  { name: 'error3', color: COLORS_MAP.error },
  { name: 'error4', color: COLORS_MAP.error },
  { name: 'fatal', color: COLORS_MAP.fatal },
  { name: 'fatal2', color: COLORS_MAP.fatal },
  { name: 'fatal3', color: COLORS_MAP.fatal },
  { name: 'fatal4', color: COLORS_MAP.fatal },
];

export function severityNumberToConfig(severityNumber) {
  return severityConfig[severityNumber] || severityConfig[5]; // default to Debug;
}
