<script>
import { GlSprintf } from '@gitlab/ui';
import {
  CRITICAL,
  HIGH,
  MEDIUM,
  LOW,
  INFO,
  UNKNOWN,
  SEVERITY_COUNT_LIMIT,
} from '~/vulnerabilities/constants';
import { s__ } from '~/locale';
import { SEVERITY_CLASS_NAME_MAP } from './constants';

export default {
  components: {
    GlSprintf,
  },
  i18n: {
    highlights: s__(
      'ciReport|%{criticalStart}critical%{criticalEnd}, %{highStart}high%{highEnd} and %{otherStart}others%{otherEnd}',
    ),
  },
  props: {
    /**
     * If provided, this will display only the count for the given severity.
     */
    showSingleSeverity: {
      type: String,
      required: false,
      default: '',
      validate: (severity) =>
        !severity || [CRITICAL, HIGH, MEDIUM, LOW, INFO, UNKNOWN].contains(severity),
    },
    highlights: {
      type: Object,
      required: true,
      validate: (highlights) =>
        [CRITICAL, HIGH].every((requiredField) => typeof highlights[requiredField] !== 'undefined'),
    },
    capped: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    criticalSeverity() {
      return this.formattedCounts(this.highlights[CRITICAL]);
    },
    highSeverity() {
      return this.formattedCounts(this.highlights[HIGH]);
    },
    otherSeverity() {
      if (typeof this.highlights.other !== 'undefined') {
        return this.formattedCounts(this.highlights.other);
      }

      let totalCounts = 0;
      let isCapped = false;

      [MEDIUM, LOW, INFO, UNKNOWN].forEach((severity) => {
        const count = this.highlights[severity];

        if (count) {
          totalCounts += count;
        }

        if (this.capped && count > SEVERITY_COUNT_LIMIT) {
          isCapped = true;
        }
      });

      return isCapped ? this.formattedCounts(totalCounts) : totalCounts;
    },
  },
  methods: {
    formattedCounts(count) {
      if (this.capped) {
        return count > SEVERITY_COUNT_LIMIT ? `${SEVERITY_COUNT_LIMIT}+` : count;
      }

      return count;
    },
  },
  cssClass: SEVERITY_CLASS_NAME_MAP,
};
</script>

<template>
  <div class="gl-font-sm">
    <strong v-if="showSingleSeverity" :class="$options.cssClass[showSingleSeverity]">{{
      formattedCounts(highlights[showSingleSeverity])
    }}</strong>
    <gl-sprintf v-else :message="$options.i18n.highlights">
      <template #critical="{ content }"
        ><strong class="gl-text-red-800">{{ criticalSeverity }} {{ content }}</strong></template
      >
      <template #high="{ content }"
        ><strong class="gl-text-red-600">{{ highSeverity }} {{ content }}</strong></template
      >
      <template #other="{ content }"
        ><strong>{{ otherSeverity }} {{ content }}</strong></template
      >
    </gl-sprintf>
  </div>
</template>
