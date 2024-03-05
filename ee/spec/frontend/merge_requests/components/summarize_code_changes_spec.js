import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { createMockSubscription } from 'mock-apollo-client';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { CONTENT_EDITOR_PASTE } from '~/vue_shared/constants';
import markdownEditorEventHub from '~/vue_shared/components/markdown/eventhub';
import { updateText } from '~/lib/utils/text_markdown';
import SummarizeCodeChanges from 'ee/merge_requests/components/summarize_code_changes.vue';
import aiActionMutation from 'ee/graphql_shared/mutations/ai_action.mutation.graphql';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';

jest.mock('~/lib/utils/text_markdown');
jest.mock('~/vue_shared/components/markdown/eventhub');

Vue.use(VueApollo);

let wrapper;
let aiResponseSubscriptionHandler;
let aiActionMutationHandler;

function createComponent() {
  aiResponseSubscriptionHandler = createMockSubscription();
  aiActionMutationHandler = jest.fn().mockResolvedValue({ data: { aiAction: { errors: [] } } });
  const mockApollo = createMockApollo([[aiActionMutation, aiActionMutationHandler]]);

  mockApollo.defaultClient.setRequestHandler(
    aiResponseSubscription,
    () => aiResponseSubscriptionHandler,
  );

  wrapper = mountExtended(SummarizeCodeChanges, {
    apolloProvider: mockApollo,
    provide: {
      projectId: '1',
      sourceBranch: 'test-source-branch',
      targetBranch: 'test-target-branch',
    },
  });
}

const findButton = () => wrapper.findByTestId('summarize-button');

describe('Merge request summarize code changes', () => {
  beforeEach(() => {
    window.gon = { current_user_id: 1 };
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  it('calls apollo mutation on click', async () => {
    createComponent();

    findButton().trigger('click');

    await waitForPromises();

    expect(aiActionMutationHandler).toHaveBeenCalled();
  });

  it('sets button as loading on click', async () => {
    createComponent();

    findButton().trigger('click');

    await waitForPromises();

    expect(findButton().props('loading')).toBe(true);
  });

  describe('when textarea exists', () => {
    beforeEach(() => {
      setHTMLFixture('<textarea class="js-gfm-input"></textarea>');
    });

    it('calls insertMarkdownText after subscription receives data', async () => {
      createComponent();

      await findButton().trigger('click');

      aiResponseSubscriptionHandler.next({
        data: {
          aiCompletionResponse: {
            id: 1,
            requestId: 1,
            content: 'AI generated content',
            errors: [],
            role: '',
            timestamp: '',
            type: '',
            chunkId: '',
            extras: {
              sources: [],
            },
          },
        },
      });

      await waitForPromises();

      expect(updateText).toHaveBeenCalledWith({
        textArea: document.querySelector('.js-gfm-input'),
        tag: 'AI generated content',
        cursorOffset: 0,
        wrap: false,
      });
    });
  });

  describe('when textarea does not exists', () => {
    beforeEach(() => {
      setHTMLFixture('<div class="js-gfm-input"></div>');
    });

    it('calls insertMarkdownText after subscription receives data', async () => {
      createComponent();

      await findButton().trigger('click');

      aiResponseSubscriptionHandler.next({
        data: {
          aiCompletionResponse: {
            id: 1,
            requestId: 1,
            content: 'AI generated content',
            errors: [],
            role: '',
            timestamp: '',
            type: '',
            chunkId: '',
            extras: {
              sources: [],
            },
          },
        },
      });

      await waitForPromises();

      expect(markdownEditorEventHub.$emit).toHaveBeenCalledWith(
        CONTENT_EDITOR_PASTE,
        'AI generated content',
      );
    });
  });
});
