import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { v4 as uuidv4 } from 'uuid';
import { GlExperimentBadge, GlFormGroup } from '@gitlab/ui';

import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockTracking } from 'helpers/tracking_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_action';
import generateCubeQueryMutation from 'ee/analytics/analytics_dashboards/graphql/mutations/generate_cube_query.mutation.graphql';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import AiCubeQueryGenerator from 'ee/analytics/analytics_dashboards/components/visualization_designer/ai_cube_query_generator.vue';
import { TEST_VISUALIZATION } from 'ee_jest/analytics/analytics_dashboards/mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('uuid');
jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_action');

describe('AiCubeQueryGenerator', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  const prompt = 'Count of page views grouped weekly';
  const generatedQuery = TEST_VISUALIZATION().data.query;
  const error = new Error('oh no it failed!!1!');

  let trackingSpy;
  const generateCubeQueryMutationHandlerMock = jest.fn();
  const aiResponseSubscriptionHandlerMock = jest.fn();

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findGenerateCubeQueryPromptInput = () =>
    wrapper.findByTestId('generate-cube-query-prompt-input');
  const findGenerateCubeQuerySubmitButton = () =>
    wrapper.findByTestId('generate-cube-query-submit-button');
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findLearnMoreLink = () => wrapper.findByTestId('generate-cube-query-learn-more-link');

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(AiCubeQueryGenerator, {
      provide: {
        namespaceId: 'gid://gitlab/Namespace/1',
        currentUserId: 1,
      },
      apolloProvider: createMockApollo([
        [generateCubeQueryMutation, generateCubeQueryMutationHandlerMock],
        [aiResponseSubscription, aiResponseSubscriptionHandlerMock],
      ]),
      propsData: {
        value: '',
        warnBeforeReplacingQuery: false,
        ...props,
      },
      stubs: {
        GlFormGroup,
      },
    });
  };

  beforeEach(() => {
    uuidv4.mockImplementation(() => 'mock-uuid');
    trackingSpy = mockTracking(undefined, window.document, jest.spyOn);
  });

  afterEach(() => {
    generateCubeQueryMutationHandlerMock.mockReset();
    aiResponseSubscriptionHandlerMock.mockReset();
    confirmAction.mockReset();
  });

  it('renders an experiment badge', () => {
    createWrapper();

    expect(findExperimentBadge().exists()).toBe(true);
  });

  it('renders a "learn more" link', () => {
    createWrapper();

    expect(findLearnMoreLink().text()).toBe('Learn more');
    expect(findLearnMoreLink().attributes('href')).toBe(
      '/help/user/analytics/analytics_dashboards#generate-a-custom-visualization-with-gitlab-duo',
    );
  });

  describe('when no prompt has been entered', () => {
    beforeEach(() => {
      createWrapper();
      findGenerateCubeQuerySubmitButton().vm.$emit('click');

      return waitForPromises();
    });

    it('does not send a request', () => {
      expect(generateCubeQueryMutationHandlerMock).not.toHaveBeenCalled();
    });

    it('shows a validation error', () => {
      expect(findFormGroup().attributes('state')).toBeUndefined();
      expect(findFormGroup().attributes('invalidfeedback')).toBe('Enter a prompt to continue.');
    });
  });

  describe('when visualization designer has existing unsaved changes', () => {
    beforeEach(() => {
      createWrapper({ warnBeforeReplacingQuery: true });
    });

    it('asks for confirmation when there are unsaved changes', () => {
      findGenerateCubeQueryPromptInput().vm.$emit('input', prompt);
      findGenerateCubeQuerySubmitButton().vm.$emit('click');

      expect(confirmAction).toHaveBeenCalledWith(
        'Would you like to replace your existing selection with a new visualization generated through GitLab Duo?',
        {
          cancelBtnText: 'Cancel',
          primaryBtnText: 'Continue with GitLab Duo',
        },
      );
    });

    it('does not generate query when user cancels', () => {
      confirmAction.mockResolvedValue(false);

      findGenerateCubeQueryPromptInput().vm.$emit('input', prompt);
      findGenerateCubeQuerySubmitButton().vm.$emit('click');

      expect(generateCubeQueryMutationHandlerMock).not.toHaveBeenCalled();
    });

    it('generates query when user confirms', async () => {
      confirmAction.mockResolvedValue(true);

      aiResponseSubscriptionHandlerMock.mockResolvedValue({
        data: {
          aiCompletionResponse: {
            errors: [],
            content: JSON.stringify(generatedQuery),
          },
        },
      });
      findGenerateCubeQueryPromptInput().vm.$emit('input', prompt);
      findGenerateCubeQuerySubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(generateCubeQueryMutationHandlerMock).toHaveBeenCalledTimes(1);
    });
  });

  describe('when a prompt is submitted', () => {
    beforeEach(() => createWrapper());

    describe('while loading', () => {
      beforeEach(() => {
        generateCubeQueryMutationHandlerMock.mockResolvedValue({
          data: { aiAction: { errors: [], __typename: 'AiActionPayload' } },
        });
        aiResponseSubscriptionHandlerMock.mockResolvedValue({
          data: {
            aiCompletionResponse: {
              errors: [],
              content: JSON.stringify(generatedQuery),
            },
          },
        });

        findGenerateCubeQueryPromptInput().vm.$emit('input', prompt);
        findGenerateCubeQuerySubmitButton().vm.$emit('click');
      });

      it('should track the prompt has been submitted', () => {
        expect(trackingSpy).toHaveBeenCalledWith(
          undefined,
          'user_submitted_gitlab_duo_query_from_visualization_designer',
          expect.any(Object),
        );
      });

      it('sends a request to the server', () => {
        expect(generateCubeQueryMutationHandlerMock).toHaveBeenCalledWith({
          clientSubscriptionId: 'mock-uuid',
          htmlResponse: false,
          resourceId: 'gid://gitlab/Namespace/1',
          question: prompt,
        });
      });

      it('subscribes to the aiCompletionResponse subscription', () => {
        expect(aiResponseSubscriptionHandlerMock).toHaveBeenCalledWith({
          clientSubscriptionId: 'mock-uuid',
          htmlResponse: true,
          resourceId: 'gid://gitlab/Namespace/1',
          userId: 'gid://gitlab/User/1',
        });
      });

      it('shows a loading indicator', () => {
        expect(findGenerateCubeQuerySubmitButton().props('loading')).toBe(true);
        expect(findGenerateCubeQuerySubmitButton().props('icon')).toBe('');
      });
    });

    describe('when aiCompletionResponse subscription returns a value', () => {
      const mockCorrelationId = 'mock-correlation-id';
      beforeEach(() => {
        generateCubeQueryMutationHandlerMock.mockResolvedValue({
          data: { aiAction: { errors: [], __typename: 'AiActionPayload' } },
          correlationId: mockCorrelationId,
        });

        aiResponseSubscriptionHandlerMock.mockResolvedValue({
          data: {
            aiCompletionResponse: {
              errors: [],
              content: JSON.stringify(generatedQuery),
            },
          },
        });

        findGenerateCubeQueryPromptInput().vm.$emit('input', prompt);
        findGenerateCubeQuerySubmitButton().vm.$emit('click');

        return waitForPromises();
      });

      it('stops loading', () => {
        expect(findGenerateCubeQuerySubmitButton().props('loading')).toBe(false);
        expect(findGenerateCubeQuerySubmitButton().props('icon')).toBe('tanuki-ai');
      });

      it('emits generated query and correlationId', () => {
        expect(wrapper.emitted('query-generated').at(0)).toStrictEqual([
          generatedQuery,
          mockCorrelationId,
        ]);
      });
    });

    describe('when there are errors', () => {
      describe.each([
        {
          testCase: 'when generateCubeMutation returns errors',
          mockMutation: () => generateCubeQueryMutationHandlerMock.mockRejectedValue(error),
          mockSubscription: () => aiResponseSubscriptionHandlerMock.mockResolvedValue({ data: {} }),
          expectLoggedToSentry: () => expect(Sentry.captureException).toHaveBeenCalledWith(error),
        },
        {
          testCase: 'when aiCompletionResponse subscription returns errors',
          mockMutation: () =>
            generateCubeQueryMutationHandlerMock.mockResolvedValue({
              data: { aiAction: { errors: [], __typename: 'AiActionPayload' } },
            }),
          mockSubscription: () =>
            aiResponseSubscriptionHandlerMock.mockResolvedValue({
              data: { aiCompletionResponse: { errors: [error], content: undefined } },
            }),
          expectLoggedToSentry: () => expect(Sentry.captureException).toHaveBeenCalledWith(error),
        },
        {
          testCase: 'when aiCompletionResponse subscription returns a malformed CubeJS query',
          mockMutation: () =>
            generateCubeQueryMutationHandlerMock.mockResolvedValue({
              data: { aiAction: { errors: [], __typename: 'AiActionPayload' } },
            }),
          mockSubscription: () =>
            aiResponseSubscriptionHandlerMock.mockResolvedValue({
              data: {
                aiCompletionResponse: {
                  errors: [],
                  content: '{ "bad": true, malformedJson = <wtf?> }',
                },
              },
            }),
          expectLoggedToSentry: () => {
            const errorMessage = Sentry.captureException.mock.calls?.at(0)?.at(0)?.message;

            if (errorMessage.includes('Unexpected token m in JSON')) {
              // Error message for Node.js 18
              expect(errorMessage).toBe('Unexpected token m in JSON at position 15');
            } else if (errorMessage.includes('Expected double-quoted property name in JSON')) {
              // Error message for Node.js 20
              expect(errorMessage).toBe(
                'Expected double-quoted property name in JSON at position 15',
              );
            } else {
              throw new Error(`Unexpected error message: ${errorMessage}`);
            }
          },
        },
      ])('$testCase', ({ mockMutation, mockSubscription, expectLoggedToSentry }) => {
        beforeEach(() => {
          mockMutation();
          mockSubscription();

          findGenerateCubeQueryPromptInput().vm.$emit('input', prompt);
          findGenerateCubeQuerySubmitButton().vm.$emit('click');

          return waitForPromises();
        });

        it('stops loading', () => {
          expect(findGenerateCubeQuerySubmitButton().props('loading')).toBe(false);
          expect(findGenerateCubeQuerySubmitButton().props('icon')).toBe('tanuki-ai');
        });

        it('shows a validation error', () => {
          expect(findFormGroup().attributes('state')).toBeUndefined();
          expect(findFormGroup().attributes('invalidfeedback')).toBe(
            'There was a problem generating your query. Please try again.',
          );
        });

        it('logs the error to Sentry', () => expectLoggedToSentry());
      });
    });
  });

  describe('when the prompt changes', () => {
    const newPrompt = 'hello world';

    beforeEach(() => {
      createWrapper();
      return findGenerateCubeQueryPromptInput().vm.$emit('input', newPrompt);
    });

    it('emits an input event with the new prompt value', () => {
      expect(wrapper.emitted('input').at(0)).toStrictEqual([newPrompt]);
    });
  });
});
