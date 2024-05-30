<script>
import { isNumber } from 'lodash';
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
      required: false,
      default: null,
    },
    mergeTrainsCount: {
      type: Number,
      required: false,
      default: null,
    },
    mergeTrainsPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    mergeTrainsVizEnabled() {
      return this.glFeatures.mergeTrainsViz;
    },
    message() {
      if (this.mergeTrainIndex === 0) {
        return s__(
          'mrWidget|A new merge train has started and this merge request is the first of the queue.',
        );
      }

      if (this.mergeTrainsVizEnabled) {
        if (isNumber(this.mergeTrainIndex) && isNumber(this.mergeTrainsCount)) {
          return sprintf(
            s__('mrWidget|This merge request is #%{mergeTrainPosition} of %{total} in queue.'),
            {
              mergeTrainPosition: this.mergeTrainIndex + 1,
              total: this.mergeTrainsCount,
            },
          );
        }
      } else if (isNumber(this.mergeTrainIndex)) {
        return sprintf(
          s__(
            'mrWidget|Added to the merge train. There are %{mergeTrainPosition} merge requests waiting to be merged',
          ),
          {
            mergeTrainPosition: this.mergeTrainIndex + 1,
          },
        );
      }

      return null;
    },
  },
};
</script>

<template>
  <div v-if="message" class="pt-2 pb-2 pl-3 plr-3 merge-train-position-indicator">
    <div class="media-body gl-text-secondary">
      {{ message }}
      <gl-link v-if="mergeTrainsVizEnabled && mergeTrainsPath" :href="mergeTrainsPath">
        {{ s__('mrWidget|View merge train details.') }}
      </gl-link>
    </div>
  </div>
</template>
