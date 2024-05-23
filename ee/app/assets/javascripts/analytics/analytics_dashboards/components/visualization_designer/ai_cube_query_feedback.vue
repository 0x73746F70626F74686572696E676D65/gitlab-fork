<script>
import { GlButton, GlPopover } from '@gitlab/ui';

import { InternalEvents } from '~/tracking';

import {
  EVENT_LABEL_USER_FEEDBACK_GITLAB_DUO_QUERY_IN_VISUALIZATION_DESIGNER_HELPFUL,
  EVENT_LABEL_USER_FEEDBACK_GITLAB_DUO_QUERY_IN_VISUALIZATION_DESIGNER_UNHELPFUL,
  EVENT_LABEL_USER_FEEDBACK_GITLAB_DUO_QUERY_IN_VISUALIZATION_DESIGNER_WRONG,
  VISUALIZATION_DESIGNER_GITLAB_DUO_CORRELATION_PROPERTY,
} from 'ee/analytics/analytics_dashboards/constants';
import { s__ } from '~/locale';

export default {
  name: 'AiCubeQueryFeedback',
  components: {
    GlButton,
    GlPopover,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    correlationId: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      hasSubmitted: false,
    };
  },
  watch: {
    correlationId() {
      this.hasSubmitted = false;
    },
  },
  methods: {
    submitFeedback(eventLabel) {
      this.trackEvent(eventLabel, {
        label: VISUALIZATION_DESIGNER_GITLAB_DUO_CORRELATION_PROPERTY,
        property: this.correlationId,
      });

      this.hasSubmitted = true;
    },
  },
  feedbackOptions: [
    {
      icon: 'thumb-up',
      event: EVENT_LABEL_USER_FEEDBACK_GITLAB_DUO_QUERY_IN_VISUALIZATION_DESIGNER_HELPFUL,
      label: s__('ProductAnalytics|Helpful'),
      testId: 'feedback-helpful-btn',
    },
    {
      icon: 'thumb-down',
      event: EVENT_LABEL_USER_FEEDBACK_GITLAB_DUO_QUERY_IN_VISUALIZATION_DESIGNER_UNHELPFUL,
      label: s__('ProductAnalytics|Unhelpful'),
      testId: 'feedback-unhelpful-btn',
    },
    {
      icon: 'status_warning',
      event: EVENT_LABEL_USER_FEEDBACK_GITLAB_DUO_QUERY_IN_VISUALIZATION_DESIGNER_WRONG,
      label: s__('ProductAnalytics|Wrong'),
      testId: 'feedback-wrong-btn',
    },
  ],
};
</script>
<template>
  <div class="gl-display-flex gl-align-items-center gl-flex-wrap">
    <span v-if="hasSubmitted">{{ s__('ProductAnalytics|Thank you for your feedback.') }}</span>
    <template v-else>
      <div class="gl-mr-3">
        {{ s__('ProductAnalytics|How was the result?') }}
        <gl-button
          id="feedback-acknowledgement-popover-btn"
          data-testid="feedback-acknowledgement-popover-btn"
          category="tertiary"
          icon="information-o"
          :aria-label="s__('ProductAnalytics|Feedback acknowledgement')"
        />
        <gl-popover
          :show-close-button="false"
          placement="top"
          target="feedback-acknowledgement-popover-btn"
          data-testid="feedback-acknowledgement-popover"
        >
          {{
            s__(
              'ProductAnalytics|By providing feedback on AI-generated content, you acknowledge that GitLab may review the prompts you submitted alongside this feedback.',
            )
          }}
        </gl-popover>
      </div>
      <div class="gl-display-flex gl-flex-wrap gl-gap-3">
        <gl-button
          v-for="feedbackOption in $options.feedbackOptions"
          :key="feedbackOption.event"
          :icon="feedbackOption.icon"
          :data-testid="feedbackOption.testId"
          @click="submitFeedback(feedbackOption.event)"
          >{{ feedbackOption.label }}</gl-button
        >
      </div>
    </template>
  </div>
</template>
