<script>
import { GlTable, GlLink, GlLabel } from '@gitlab/ui';
import { s__ } from '~/locale';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';

const severityConfig = [
  { range: [1, 4], title: s__('ObservabilityLogs|Trace'), color: '#a4a3a8' },
  { range: [5, 8], title: s__('ObservabilityLogs|Debug'), color: '#a4a3a8' },
  { range: [9, 12], title: s__('ObservabilityLogs|Info'), color: '#428fdc' },
  { range: [13, 16], title: s__('ObservabilityLogs|Warning'), color: '#e9be74' },
  { range: [17, 20], title: s__('ObservabilityLogs|Error'), color: '#dd2b0e' },
  { range: [21, 24], title: s__('ObservabilityLogs|Fatal'), color: '#dd2b0e' },
];
const defaultSeverity = severityConfig[1]; // default: Debug

const tdClass = 'gl-px-2! gl-py-3! gl-mx-0';
const thClass = 'gl-px-2!';
export default {
  i18n: {
    title: s__('ObservabilityLogs|Logs'),
    emptyText: s__('ObservabilityLogs|No logs to display.'),
    emptyLinkText: s__('ObservabilityLogs|Check again'),
  },
  fields: [
    {
      key: 'timestamp',
      label: s__('ObservabilityLogs|Date'),
      tdAttr: { 'data-testid': 'log-timestamp' },
      // eslint-disable-next-line @gitlab/require-i18n-strings
      thClass: `${thClass} gl-w-2/20`,
      tdClass,
    },
    {
      key: 'severity_number',
      label: s__('ObservabilityLogs|Level'),
      tdAttr: { 'data-testid': 'log-level' },
      // eslint-disable-next-line @gitlab/require-i18n-strings
      thClass: `${thClass} gl-w-1/20`,
      tdClass,
    },
    {
      key: 'service_name',
      label: s__('ObservabilityLogs|Service'),
      tdAttr: { 'data-testid': 'log-service' },
      // eslint-disable-next-line @gitlab/require-i18n-strings
      thClass: `${thClass} gl-w-1/20`,
      tdClass: `${tdClass} gl-word-break-word`,
    },
    {
      key: 'body',
      label: s__('ObservabilityLogs|Message'),
      tdAttr: { 'data-testid': 'log-message' },
      // eslint-disable-next-line @gitlab/require-i18n-strings
      thClass: `${thClass} gl-w-16/20`,
      tdClass,
    },
  ],
  components: {
    GlTable,
    GlLink,
    GlLabel,
  },
  props: {
    logs: {
      required: true,
      type: Array,
    },
  },
  computed: {
    formattedLogs() {
      return this.logs.map((log) => ({
        ...log,
        timestamp: formatDate(log.timestamp),
      }));
    },
  },
  methods: {
    severityLabel(severityNumber) {
      const severity = severityConfig.find(
        ({ range }) => severityNumber >= range[0] && severityNumber <= range[1],
      );
      return severity || defaultSeverity;
    },
    onRowClicked(item) {
      this.$emit('log-selected', { fingerprint: item.fingerprint });
    },
  },
};
</script>

<template>
  <div>
    <h4 class="gl-display-block gl-md-display-none! gl-my-5">{{ $options.i18n.title }}</h4>

    <gl-table
      :items="formattedLogs"
      :fields="$options.fields"
      show-empty
      fixed
      stacked="sm"
      selectable
      select-mode="single"
      selected-variant="secondary"
      :tbody-tr-attr="{ 'data-testid': 'log-row' }"
      @row-clicked="onRowClicked"
    >
      <template #cell(severity_number)="{ item }">
        <gl-label
          :background-color="severityLabel(item.severity_number).color"
          :title="severityLabel(item.severity_number).title"
        />
      </template>

      <template #cell(body)="{ item }">
        <div class="gl-text-truncate">
          {{ item.body }}
        </div>
      </template>
      <!-- no date template -->
      <template #empty>
        <div class="gl-text-center">
          {{ $options.i18n.emptyText }}
          <gl-link @click="$emit('reload')">{{ $options.i18n.emptyLinkText }}</gl-link>
        </div>
      </template>
    </gl-table>
  </div>
</template>
