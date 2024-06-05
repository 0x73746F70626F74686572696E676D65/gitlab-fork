<script>
import {
  GlButton,
  GlExperimentBadge,
  GlFormGroup,
  GlFormTextarea,
  GlIcon,
  GlLink,
} from '@gitlab/ui';
import { v4 as uuidv4 } from 'uuid';

import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_action';
import { fetchPolicies } from '~/lib/graphql';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT, TYPENAME_USER } from '~/graphql_shared/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __, s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { InternalEvents } from '~/tracking';
import { EVENT_LABEL_USER_SUBMITTED_GITLAB_DUO_QUERY_FROM_VISUALIZATION_DESIGNER } from 'ee/analytics/analytics_dashboards/constants';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';

import generateCubeQuery from '../../graphql/mutations/generate_cube_query.mutation.graphql';

export default {
  name: 'AiCubeQueryGenerator',
  components: {
    GlButton,
    GlExperimentBadge,
    GlFormGroup,
    GlFormTextarea,
    GlIcon,
    GlLink,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    namespaceId: {
      type: String,
    },
    currentUserId: {
      type: Number,
    },
  },
  props: {
    value: {
      type: String,
      required: true,
    },
    warnBeforeReplacingQuery: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      prompt: this.value,
      error: null,
      submitting: false,
      clientSubscriptionId: uuidv4(),
      query: null,
      correlationId: null,
      skipSubscription: true,
    };
  },
  computed: {
    isValid() {
      return !this.error;
    },
    submitButtonIcon() {
      return this.submitting ? undefined : 'tanuki-ai';
    },
    hasCompletedGeneration() {
      return this.correlationId && this.query;
    },
  },
  watch: {
    value(value) {
      this.prompt = value;
    },
    prompt() {
      this.$emit('input', this.prompt);
    },
    hasCompletedGeneration(hasCompleted) {
      if (hasCompleted) {
        this.$emit('query-generated', this.query, this.correlationId);
      }
    },
  },
  methods: {
    async generateAiQuery() {
      if (this.submitting) return;
      if (!this.prompt) {
        this.error = s__('Analytics|Enter a prompt to continue.');
        return;
      }
      if (this.warnBeforeReplacingQuery) {
        const confirmed = await this.confirmReplaceExistingQuery();
        if (!confirmed) return;
      }

      this.trackEvent(EVENT_LABEL_USER_SUBMITTED_GITLAB_DUO_QUERY_FROM_VISUALIZATION_DESIGNER);
      this.skipSubscription = false;
      this.submitting = true;
      this.error = null;
      this.correlationId = null;
      this.query = null;

      try {
        const { correlationId } = await this.$apollo.mutate({
          mutation: generateCubeQuery,
          variables: {
            question: this.prompt,
            resourceId: convertToGraphQLId(TYPENAME_PROJECT, this.namespaceId),
            clientSubscriptionId: this.clientSubscriptionId,
            htmlResponse: false,
          },
        });
        this.correlationId = correlationId;
      } catch (error) {
        this.handleErrors([error]);
        this.submitting = false;
      }
    },
    handleErrors(errors) {
      errors.forEach((error) => Sentry.captureException(error));

      this.error = s__('Analytics|There was a problem generating your query. Please try again.');
    },
    confirmReplaceExistingQuery() {
      return confirmAction(
        s__(
          'Analytics|Would you like to replace your existing selection with a new visualization generated through GitLab Duo?',
        ),
        {
          primaryBtnText: __('Continue with GitLab Duo'),
          cancelBtnText: __('Cancel'),
        },
      );
    },
  },
  apollo: {
    $subscribe: {
      generateCubeQuery: {
        query: aiResponseSubscription,
        // Apollo wants to write the subscription result to the cache, but we have none because we also
        // don't have a query. We only use this subscription as a notification.
        fetchPolicy: fetchPolicies.NO_CACHE,
        skip() {
          return this.skipSubscription;
        },
        variables() {
          return {
            resourceId: convertToGraphQLId(TYPENAME_PROJECT, this.namespaceId),
            userId: convertToGraphQLId(TYPENAME_USER, this.currentUserId),
            clientSubscriptionId: this.clientSubscriptionId,
          };
        },
        error(error) {
          this.handleErrors([error]);
        },
        result({ data }) {
          const { errors = [], content } = data.aiCompletionResponse || {};

          if (errors.length) {
            this.handleErrors(errors);
            this.submitting = false;
            return;
          }

          if (!content) {
            return;
          }

          this.submitting = false;

          try {
            this.query = JSON.parse(content);
          } catch (error) {
            this.handleErrors([error]);
          }
        },
      },
    },
  },
  helpPageUrl: helpPagePath('user/analytics/analytics_dashboards', {
    anchor: 'generate-a-custom-visualization-with-gitlab-duo',
  }),
};
</script>

<template>
  <section>
    <gl-form-group :optional="true" :state="isValid" :invalid-feedback="error" class="gl-mb-0">
      <template #label>
        <gl-icon name="tanuki-ai" class="gl-mr-1" />
        {{ s__('Analytics|Create with GitLab Duo (optional)') }}
        <gl-experiment-badge />
      </template>
      <p class="gl-mb-3">
        {{
          s__(
            'Analytics|GitLab Duo may be used to help generate your visualization. You can prompt Duo with your desired data, as well as any dimensions or additional groupings of that data. You may also edit the result as needed.',
          )
        }}
        <gl-link data-testid="generate-cube-query-learn-more-link" :href="$options.helpPageUrl">{{
          __('Learn more')
        }}</gl-link
        >.
      </p>
      <gl-form-textarea
        v-model="prompt"
        :placeholder="s__('Analytics|Example: Number of users over time, grouped weekly')"
        :submit-on-enter="true"
        :state="isValid"
        no-resize
        class="gl-w-full gl-md-max-w-70p gl-lg-w-30p gl-min-w-20"
        data-testid="generate-cube-query-prompt-input"
        @submit="generateAiQuery"
      />
    </gl-form-group>
    <gl-button
      :loading="submitting"
      category="secondary"
      variant="confirm"
      :icon="submitButtonIcon"
      class="gl-mt-3"
      data-testid="generate-cube-query-submit-button"
      @click="generateAiQuery"
      >{{ s__('Analytics|Generate with Duo') }}</gl-button
    >
  </section>
</template>
