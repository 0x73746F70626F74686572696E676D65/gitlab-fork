<script>
import { GlButton, GlBadge, GlIcon, GlPopover, GlOutsideDirective as Outside } from '@gitlab/ui';
import { CONTENT_EDITOR_PASTE } from '~/vue_shared/constants';
import { updateText } from '~/lib/utils/text_markdown';
import { TYPENAME_PROJECT, TYPENAME_USER } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import markdownEditorEventHub from '~/vue_shared/components/markdown/eventhub';
import aiActionMutation from 'ee/graphql_shared/mutations/ai_action.mutation.graphql';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';

export default {
  components: {
    GlButton,
    GlBadge,
    GlIcon,
    GlPopover,
    UserCalloutDismisser,
  },
  directives: { Outside },
  inject: ['projectId', 'sourceBranch', 'targetBranch'],
  apollo: {
    $subscribe: {
      aiCompletionResponse: {
        query: aiResponseSubscription,
        variables() {
          return {
            resourceId: this.resourceId,
            userId: this.userId,
            htmlResponse: false,
          };
        },
        result({ data: { aiCompletionResponse } }) {
          if (aiCompletionResponse) {
            const { content } = aiCompletionResponse;
            const textArea = document.querySelector('textarea.js-gfm-input');

            if (textArea) {
              updateText({
                textArea,
                tag: content,
                cursorOffset: 0,
                wrap: false,
              });
            } else {
              markdownEditorEventHub.$emit(CONTENT_EDITOR_PASTE, content);
            }

            this.loading = false;
          }
        },
      },
    },
  },
  data() {
    return {
      loading: false,
    };
  },
  computed: {
    resourceId() {
      return convertToGraphQLId(TYPENAME_PROJECT, this.projectId);
    },
    userId() {
      return convertToGraphQLId(TYPENAME_USER, gon.current_user_id);
    },
  },
  methods: {
    onClick() {
      this.loading = true;
      this.$apollo.mutate({
        mutation: aiActionMutation,
        variables: {
          input: {
            summarizeNewMergeRequest: {
              resourceId: this.resourceId,
              sourceProjectId: this.projectId,
              sourceBranch: this.sourceBranch,
              targetBranch: this.targetBranch,
            },
          },
        },
      });
    },
  },
};
</script>

<template>
  <div class="gl-ml-auto gl-mb-4">
    <gl-button
      ref="button"
      icon="tanuki-ai"
      :loading="loading"
      data-testid="summarize-button"
      @click="onClick"
    >
      {{ __('Summarize code changes') }}
      <gl-badge variants="neutral" class="gl-ml-2">{{ __('Beta') }}</gl-badge>
    </gl-button>
    <user-callout-dismisser feature-name="summarize_code_changes">
      <template #default="{ dismiss, shouldShowCallout }">
        <gl-popover
          v-if="shouldShowCallout"
          :target="$refs.button"
          :show="shouldShowCallout"
          show-close-button
          triggers="manual"
          placement="top"
          :css-classes="['gl-max-w-48']"
          @close-button-clicked="dismiss"
        >
          <div v-outside="() => dismiss()">
            <p class="gl-mb-2 -gl-mt-3">
              <gl-icon name="tanuki-ai" class="gl-mr-2" />
              <strong>{{ __('Introducing: Summarize code changes') }}</strong>
            </p>
            <p class="gl-mb-0">{{ __('See an AI-generated summary of your code changes.') }}</p>
          </div>
        </gl-popover>
      </template>
    </user-callout-dismisser>
  </div>
</template>
