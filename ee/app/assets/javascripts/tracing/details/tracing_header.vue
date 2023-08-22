<script>
import { GlCard, GlBadge } from '@gitlab/ui';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { s__ } from '~/locale';
import { formatTraceDuration } from '../trace_utils';

const CARD_CLASS = 'gl-mr-7 gl-w-3/20 gl-min-w-fit';
const HEADER_CLASS = 'gl-p-2 gl-font-bold gl-flex gl-justify-center gl-items-center';
const BODY_CLASS =
  'gl-flex gl-justify-center gl-items-center gl-flex-direction-column gl-my-0 gl-p-4 gl-font-bold gl-text-center gl-flex-grow-1 gl-font-lg';

export default {
  CARD_CLASS,
  HEADER_CLASS,
  BODY_CLASS,
  components: {
    GlCard,
    GlBadge,
  },
  i18n: {
    inProgress: s__('Tracing|In progress'),
  },
  props: {
    trace: {
      required: true,
      type: Object,
    },
    incomplete: {
      required: true,
      type: Boolean,
    },
  },
  computed: {
    title() {
      return `${this.trace.service_name} : ${this.trace.operation}`;
    },
    traceDate() {
      return formatDate(this.trace.timestamp, 'mmm d, yyyy');
    },
    traceTime() {
      return formatDate(this.trace.timestamp, 'H:MM:ss.l Z');
    },
    traceDuration() {
      return formatTraceDuration(this.trace.duration_nano);
    },
  },
};
</script>

<template>
  <div class="gl-mb-6">
    <h1>
      {{ title }}
      <gl-badge v-if="incomplete" variant="warning" class="gl-ml-3 gl-align-middle">{{
        $options.i18n.inProgress
      }}</gl-badge>
    </h1>

    <div class="gl-display-flex gl-flex-wrap gl-justify-content-center gl-my-7 gl-gap-y-6">
      <gl-card
        data-testid="trace-date-card"
        :class="$options.CARD_CLASS"
        :body-class="$options.BODY_CLASS"
        :header-class="$options.HEADER_CLASS"
      >
        <template #header>
          {{ __('Trace start') }}
        </template>

        <template #default>
          <span>{{ traceDate }}</span>
          <span class="gl-text-secondary gl-font-normal">{{ traceTime }}</span>
        </template>
      </gl-card>

      <gl-card
        data-testid="trace-duration-card"
        :class="$options.CARD_CLASS"
        :body-class="$options.BODY_CLASS"
        :header-class="$options.HEADER_CLASS"
      >
        <template #header>
          {{ __('Duration') }}
        </template>

        <template #default>
          <span>{{ traceDuration }}</span>
        </template>
      </gl-card>

      <gl-card
        data-testid="trace-spans-card"
        :class="$options.CARD_CLASS"
        :body-class="$options.BODY_CLASS"
        :header-class="$options.HEADER_CLASS"
      >
        <template #header>
          {{ __('Total spans') }}
        </template>

        <template #default>
          <span>{{ trace.total_spans }}</span>
        </template>
      </gl-card>
    </div>
  </div>
</template>
