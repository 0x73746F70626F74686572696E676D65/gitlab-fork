<script>
import { GlLink, GlTooltip, GlIcon } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';

export default {
  components: {
    CiIcon,
    GlIcon,
    GlLink,
    GlTooltip,
  },
  props: {
    lastPipeline: {
      type: Object,
      required: true,
    },
  },
  relations: {
    current: __('Current Project'),
    downstream: __('Downstream'),
    upstream: __('Upstream'),
  },
  computed: {
    downstreamPipelines() {
      return this.lastPipeline.triggered;
    },
    upstreamPipeline() {
      return this.lastPipeline.triggered_by;
    },
    hasDownstreamPipelines() {
      return this.downstreamPipelines && this.downstreamPipelines.length > 0;
    },
    hasExtraDownstream() {
      return this.downstreamCount > this.shownDownstreamCount;
    },
    /*
      Returns a subset of the downstream pipelines, because we can only fit 5 of them
      on a mobile screen before we have to truncate.
    */
    shownDownstreamPipelines() {
      return this.downstreamPipelines.slice(0, 5);
    },
    shownDownstreamCount() {
      return this.shownDownstreamPipelines.length;
    },
    downstreamCount() {
      return this.downstreamPipelines.length;
    },
    /*
      Returns the number of extra downstream status to be shown in the icon
      The plus sign is only shown on single digits, otherwise the number is cut off
    */
    extraDownstreamText() {
      const extra = this.downstreamCount - this.shownDownstreamCount;
      const plus = extra < 10 ? '+' : '';
      return `${plus}${extra}`;
    },
    extraDownstreamTitle() {
      const extra = this.downstreamCount - this.shownDownstreamCount;

      return sprintf(__('%{extra} more downstream pipelines'), {
        extra,
      });
    },
  },
};
</script>
<template>
  <div class="dashboard-card-footer py-1 px-2 mt-3 bg-white">
    <template v-if="upstreamPipeline">
      <gl-link
        ref="upstreamStatus"
        :href="upstreamPipeline.details.status.details_path"
        class="gl-inline-block align-middle"
      >
        <ci-icon :status="upstreamPipeline.details.status" class="js-upstream-pipeline-status" />
      </gl-link>
      <gl-tooltip :target="() => $refs.upstreamStatus">
        <div class="bold">{{ $options.relations.upstream }}</div>
        <div>{{ upstreamPipeline.details.status.tooltip }}</div>
        <div class="text-tertiary">{{ upstreamPipeline.project.full_name }}</div>
      </gl-tooltip>

      <gl-icon name="arrow-right" class="dashboard-card-footer-arrow align-middle mx-1" />
    </template>

    <ci-icon
      ref="status"
      :status="lastPipeline.details.status"
      show-status-text
      class="gl-inline-block align-middle"
    />
    <gl-tooltip :target="() => $refs.status">
      <div class="bold">{{ $options.relations.current }}</div>
      <div>{{ lastPipeline.details.status.tooltip }}</div>
    </gl-tooltip>

    <template v-if="hasDownstreamPipelines">
      <gl-icon name="arrow-right" class="dashboard-card-footer-arrow align-middle mx-1" />

      <div
        v-for="(pipeline, index) in shownDownstreamPipelines"
        :key="pipeline.id"
        :style="`z-index: ${shownDownstreamPipelines.length + 1 - index}`"
        class="dashboard-card-footer-downstream position-relative gl-inline"
      >
        <gl-link
          ref="downstreamStatus"
          :href="pipeline.details.status.details_path"
          class="gl-inline-block align-middle"
        >
          <ci-icon :status="pipeline.details.status" class="js-downstream-pipeline-status" />
        </gl-link>
        <gl-tooltip :target="() => $refs.downstreamStatus[index]">
          <div class="bold">{{ $options.relations.downstream }}</div>
          <div>{{ pipeline.details.status.tooltip }}</div>
          <div class="text-tertiary">{{ pipeline.project.full_name }}</div>
        </gl-tooltip>
      </div>
      <div v-if="hasExtraDownstream" class="gl-inline">
        <gl-link
          ref="extraDownstream"
          :href="lastPipeline.details.status.details_path"
          class="dashboard-card-footer-extra rounded-circle gl-inline-block bold align-middle text-white text-center js-downstream-extra-icon"
        >
          {{ extraDownstreamText }}
        </gl-link>
        <gl-tooltip :target="() => $refs.extraDownstream">
          {{ extraDownstreamTitle }}
        </gl-tooltip>
      </div>
    </template>
  </div>
</template>
