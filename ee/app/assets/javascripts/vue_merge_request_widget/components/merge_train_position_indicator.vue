<script>
import { GlLink } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

export default {
  name: 'MergeTrainPositionIndicator',
  components: {
    GlLink,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    mergeTrainIndex: {
      type: Number,
      required: true,
    },
    mergeTrainsCount: {
      type: Number,
      required: true,
    },
    mergeTrainsPath: {
      type: String,
      required: true,
    },
  },
  computed: {
    mergeTrainsVizEnabled() {
      return this.glFeatures.mergeTrainsViz;
    },
    message() {
      const messageBeginningTrainPosition = s__(
        'mrWidget|A new merge train has started and this merge request is the first of the queue.',
      );
      const messageAddedTrainPosition = sprintf(
        s__('mrWidget|This merge request is #%{mergeTrainPosition} of %{total} in queue.'),
        {
          mergeTrainPosition: this.mergeTrainIndex + 1,
          total: this.mergeTrainsCount,
        },
      );

      return this.mergeTrainIndex === 0 ? messageBeginningTrainPosition : messageAddedTrainPosition;
    },
    legacyMessage() {
      const messageBeginningTrainPosition = s__(
        'mrWidget|A new merge train has started and this merge request is the first of the queue.',
      );
      const messageAddedTrainPosition = sprintf(
        s__(
          'mrWidget|Added to the merge train. There are %{mergeTrainPosition} merge requests waiting to be merged',
        ),
        {
          mergeTrainPosition: this.mergeTrainIndex + 1,
        },
      );

      return this.mergeTrainIndex === 0 ? messageBeginningTrainPosition : messageAddedTrainPosition;
    },
    messageHandler() {
      return this.mergeTrainsVizEnabled ? this.message : this.legacyMessage;
    },
  },
};
</script>

<template>
  <div class="pt-2 pb-2 pl-3 plr-3 merge-train-position-indicator">
    <div class="media-body gl-text-secondary">
      {{ messageHandler }}
      <gl-link v-if="mergeTrainsVizEnabled" :href="mergeTrainsPath">
        {{ s__('mrWidget|View merge train details.') }}
      </gl-link>
    </div>
  </div>
</template>
