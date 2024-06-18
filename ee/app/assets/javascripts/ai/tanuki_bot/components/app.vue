<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { GlDuoChat } from '@gitlab/ui';
import { v4 as uuidv4 } from 'uuid';
import { __, s__ } from '~/locale';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import { helpPagePath } from '~/helpers/help_page_helper';
import { helpCenterState } from '~/super_sidebar/constants';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import aiResponseStreamSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response_stream.subscription.graphql';
import DuoChatCallout from 'ee/ai/components/global_callout/duo_chat_callout.vue';
import getAiMessages from 'ee/ai/graphql/get_ai_messages.query.graphql';
import chatMutation from 'ee/ai/graphql/chat.mutation.graphql';
import duoUserFeedbackMutation from 'ee/ai/graphql/duo_user_feedback.mutation.graphql';
import Tracking from '~/tracking';
import {
  i18n,
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAN_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
} from 'ee/ai/constants';
import { TANUKI_BOT_TRACKING_EVENT_NAME, MESSAGE_TYPES } from '../constants';

export default {
  name: 'TanukiBotChatApp',
  i18n: {
    gitlabChat: s__('DuoChat|GitLab Duo Chat'),
    giveFeedback: s__('DuoChat|Give feedback'),
    source: __('Source'),
    experiment: __('Experiment'),
    askAQuestion: s__('DuoChat|Ask a question about GitLab'),
    exampleQuestion: s__('DuoChat|For example, %{linkStart}what is a fork%{linkEnd}?'),
    whatIsAForkQuestion: s__('DuoChat|What is a fork?'),
    GENIE_CHAT_LEGAL_GENERATED_BY_AI: i18n.GENIE_CHAT_LEGAL_GENERATED_BY_AI,
    predefinedPrompts: [
      __('How do I change my password in GitLab?'),
      __('How do I fork a project?'),
      __('How do I clone a repository?'),
      __('How do I create a template?'),
    ],
  },
  helpPagePath: helpPagePath('policy/experiment-beta-support', { anchor: 'beta' }),
  components: {
    GlDuoChat,
    DuoChatCallout,
  },
  mixins: [Tracking.mixin()],
  provide() {
    return {
      renderGFM,
    };
  },
  props: {
    userId: {
      type: String,
      required: true,
    },
    resourceId: {
      type: String,
      required: false,
      default: null,
    },
  },
  apollo: {
    $subscribe: {
      aiCompletionResponse: {
        query: aiResponseSubscription,
        variables() {
          return {
            userId: this.userId,
            aiAction: 'CHAT',
          };
        },
        result({ data }) {
          this.addDuoChatMessage(data?.aiCompletionResponse);
          if (data?.aiCompletionResponse?.role.toLowerCase() === MESSAGE_TYPES.TANUKI) {
            this.responseCompleted = data?.aiCompletionResponse?.requestId;
          }
        },
        error(err) {
          this.error = err.toString();
        },
        skip() {
          return !this.helpCenterState.showTanukiBotChatDrawer;
        },
      },
      aiCompletionResponseStream: {
        query: aiResponseStreamSubscription,
        variables() {
          return {
            userId: this.userId,
            resourceId: this.resourceId || this.userId,
            clientSubscriptionId: this.clientSubscriptionId,
          };
        },
        result({ data }) {
          if (data?.aiCompletionResponse?.requestId !== this.responseCompleted) {
            this.addDuoChatMessage(data?.aiCompletionResponse);
          }
          if (data?.aiCompletionResponse?.chunkId && !this.isResponseTracked) {
            performance.mark('response-received');
            performance.measure('prompt-to-response', 'prompt-sent', 'response-received');
            const [{ duration }] = performance.getEntriesByName('prompt-to-response');
            this.track('ai_response_time', {
              property: data.aiCompletionResponse.requestId,
              value: duration,
            });
            performance.clearMarks();
            performance.clearMeasures();
            this.isResponseTracked = true;
          }
        },
        error(err) {
          this.error = err.toString();
        },
        skip() {
          return !this.helpCenterState.showTanukiBotChatDrawer;
        },
      },
    },
    aiMessages: {
      query: getAiMessages,
      result({ data }) {
        if (data?.aiMessages?.nodes) {
          this.setMessages(data.aiMessages.nodes);
        }
      },
      error(err) {
        this.error = err.toString();
      },
    },
  },
  data() {
    return {
      helpCenterState,
      clientSubscriptionId: uuidv4(),
      toolName: i18n.GITLAB_DUO,
      error: '',
      responseCompleted: undefined,
      isResponseTracked: false,
    };
  },
  computed: {
    ...mapState(['loading', 'messages']),
  },
  methods: {
    ...mapActions(['addDuoChatMessage', 'setMessages', 'setLoading']),
    isClearOrResetMessage(question) {
      return [
        GENIE_CHAT_CLEAN_MESSAGE,
        GENIE_CHAT_CLEAR_MESSAGE,
        GENIE_CHAT_RESET_MESSAGE,
      ].includes(question);
    },
    onSendChatPrompt(question) {
      this.responseCompleted = undefined;
      performance.mark('prompt-sent');
      this.isResponseTracked = false;

      if (!this.isClearOrResetMessage(question)) {
        this.setLoading();
      }
      this.$apollo
        .mutate({
          mutation: chatMutation,
          variables: {
            question,
            resourceId: this.resourceId || this.userId,
            clientSubscriptionId: this.clientSubscriptionId,
          },
        })
        .then(({ data: { aiAction = {} } = {} }) => {
          if (!this.isClearOrResetMessage(question)) {
            this.track('submit_gitlab_duo_question', {
              property: aiAction.requestId,
            });
          }
          if ([GENIE_CHAT_CLEAN_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE].includes(question)) {
            this.$apollo.queries.aiMessages.refetch();
          } else {
            this.addDuoChatMessage({
              ...aiAction,
              content: question,
            });
          }
        })
        .catch((err) => {
          this.error = err.toString();
          this.addDuoChatMessage({
            content: question,
          });
          this.setLoading(false);
        });
    },
    onChatClose() {
      this.helpCenterState.showTanukiBotChatDrawer = false;
    },
    onCalloutDismissed() {
      this.helpCenterState.showTanukiBotChatDrawer = true;
    },
    onTrackFeedback({ feedbackChoices, didWhat, improveWhat, message } = {}) {
      if (message) {
        const { id, requestId, extras, role, content } = message;
        this.$apollo
          .mutate({
            mutation: duoUserFeedbackMutation,
            variables: {
              input: {
                aiMessageId: id,
                trackingEvent: {
                  category: TANUKI_BOT_TRACKING_EVENT_NAME,
                  action: 'click_button',
                  label: 'response_feedback',
                  property: feedbackChoices.join(','),
                  extra: {
                    improveWhat,
                    didWhat,
                    prompt_location: 'after_content',
                  },
                },
              },
            },
          })
          .catch(() => {
            // silent failure because of fire and forget
          });

        this.addDuoChatMessage({
          requestId,
          role,
          content,
          extras: { ...extras, hasFeedback: true },
        });
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-duo-chat
      v-if="helpCenterState.showTanukiBotChatDrawer"
      id="duo-chat"
      :title="$options.i18n.gitlabChat"
      :messages="messages"
      :error="error"
      :is-loading="loading"
      :predefined-prompts="$options.i18n.predefinedPrompts"
      :badge-type="null"
      :tool-name="toolName"
      class="duo-chat-container"
      @send-chat-prompt="onSendChatPrompt"
      @chat-hidden="onChatClose"
      @track-feedback="onTrackFeedback"
    />
    <duo-chat-callout @callout-dismissed="onCalloutDismissed" />
  </div>
</template>
