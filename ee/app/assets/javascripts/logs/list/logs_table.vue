<script>
import { GlTable, GlLabel } from '@gitlab/ui';
import { s__ } from '~/locale';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { severityNumberToConfig } from '../utils';

const tdClass = 'gl-px-2! gl-py-3! gl-mx-0';
const thClass = 'gl-px-2!';
export default {
  i18n: {
    title: s__('ObservabilityLogs|Logs'),
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
      tdClass: `${tdClass} gl-break-anywhere`,
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
    severityConfig(severityNumber) {
      return severityNumberToConfig(severityNumber);
    },
    onRowClicked(item) {
      this.$emit('log-selected', { fingerprint: item.fingerprint });
    },
  },
};
</script>

<template>
  <div>
    <h4 class="gl-block md:!gl-hidden gl-my-5">{{ $options.i18n.title }}</h4>

    <gl-table
      :items="formattedLogs"
      :fields="$options.fields"
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
          :background-color="severityConfig(item.severity_number).color"
          :title="severityConfig(item.severity_number).name"
        />
      </template>

      <template #cell(body)="{ item }">
        <div class="gl-text-truncate">
          {{ item.body }}
        </div>
      </template>
    </gl-table>
  </div>
</template>
