import { GlLoadingIcon, GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import MockAdapter from 'axios-mock-adapter';
import VueApollo from 'vue-apollo';
import { createMockSubscription } from 'mock-apollo-client';
import { createMockDirective } from 'helpers/vue_mock_directive';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import aiResolveVulnerability from 'ee/vulnerabilities/graphql/ai_resolve_vulnerability.mutation.graphql';
import Api from 'ee/api';
import vulnerabilityStateMutations from 'ee/security_dashboard/graphql/mutate_vulnerability_state';
import SplitButton from 'ee/vue_shared/security_reports/components/split_button.vue';
import StatusBadge from 'ee/vue_shared/security_reports/components/status_badge.vue';
import Header, { CLIENT_SUBSCRIPTION_ID } from 'ee/vulnerabilities/components/header.vue';
import ResolutionAlert from 'ee/vulnerabilities/components/resolution_alert.vue';
import StatusDescription from 'ee/vulnerabilities/components/status_description.vue';
import VulnerabilityStateDropdown from 'ee/vulnerabilities/components/vulnerability_state_dropdown.vue';
import { FEEDBACK_TYPES, VULNERABILITY_STATE_OBJECTS } from 'ee/vulnerabilities/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import UsersMockHelper from 'helpers/user_mock_data_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { convertObjectPropsToSnakeCase } from '~/lib/utils/common_utils';
import download from '~/lib/utils/downloader';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { visitUrl } from '~/lib/utils/url_utility';
import chatMutation from 'ee/ai/graphql/chat.mutation.graphql';
import { MOCK_TANUKI_BOT_MUTATATION_RES } from 'ee_jest/ai/tanuki_bot/mock_data';
import { helpCenterState } from '~/super_sidebar/constants';
import {
  getVulnerabilityStatusMutationResponse,
  dismissalDescriptions,
  getAiSubscriptionResponse,
  AI_SUBSCRIPTION_ERROR_RESPONSE,
  MUTATION_AI_ACTION_DEFAULT_RESPONSE,
  MUTATION_AI_ACTION_GLOBAL_ERROR,
  MUTATION_AI_ACTION_ERROR,
} from './mock_data';

Vue.use(VueApollo);

const MOCK_SUBSCRIPTION_RESPONSE = getAiSubscriptionResponse(
  'http://gdk.test:3000/secure-ex/webgoat.net/-/merge_requests/5',
);
const vulnerabilityStateEntries = Object.entries(VULNERABILITY_STATE_OBJECTS);
const mockAxios = new MockAdapter(axios);
jest.mock('~/alert');
jest.mock('~/lib/utils/downloader');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

describe('Vulnerability Header', () => {
  let wrapper;

  const defaultVulnerability = {
    id: 1,
    createdAt: new Date().toISOString(),
    reportType: 'dast',
    state: 'detected',
    createMrUrl: '/create_mr_url',
    newIssueUrl: '/new_issue_url',
    projectFingerprint: 'abc123',
    uuid: 'xxxxxxxx-xxxx-5xxx-xxxx-xxxxxxxxxxxx',
    pipeline: {
      id: 2,
      createdAt: new Date().toISOString(),
      url: 'pipeline_url',
      sourceBranch: 'main',
    },
    description: 'description',
    identifiers: 'identifiers',
    links: 'links',
    location: 'location',
    name: 'name',
    mergeRequestLinks: [],
    stateTransitions: [],
  };

  const diff = 'some diff to download';

  const getVulnerability = ({ canCreateMergeRequest, canDownloadPatch, canAdmin = true } = {}) => ({
    remediations: canCreateMergeRequest || canDownloadPatch ? [{ diff }] : null,
    state: canDownloadPatch ? 'detected' : 'resolved',
    mergeRequestLinks: canCreateMergeRequest || canDownloadPatch ? [] : [{}],
    mergeRequestFeedback: canCreateMergeRequest ? null : {},
    canAdmin,
    ...(canDownloadPatch && canCreateMergeRequest === undefined ? { createMrUrl: '' } : {}),
  });

  const createApolloProvider = (...queries) => {
    return createMockApollo([...queries]);
  };

  const createRandomUser = () => {
    const user = UsersMockHelper.createRandomUser();
    const url = Api.buildUrl(Api.userPath).replace(':id', user.id);
    mockAxios.onGet(url).replyOnce(HTTP_STATUS_OK, user);

    return user;
  };

  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findStatusBadge = () => wrapper.findComponent(StatusBadge);
  const findSplitButton = () => wrapper.findComponent(SplitButton);
  const findStateButton = () => wrapper.findComponent(GlCollapsibleListbox);
  const findResolutionAlert = () => wrapper.findComponent(ResolutionAlert);
  const findStatusDescription = () => wrapper.findComponent(StatusDescription);

  const changeStatus = (action) => {
    const dropdown = wrapper.findComponent(VulnerabilityStateDropdown);
    dropdown.vm.$emit('change', { action });
  };

  const createWrapper = ({ vulnerability = {}, apolloProvider, glFeatures, glAbilities }) => {
    wrapper = shallowMount(Header, {
      apolloProvider,
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        vulnerability: {
          ...defaultVulnerability,
          ...vulnerability,
        },
      },
      provide: {
        dismissalDescriptions,
        glFeatures: {
          explainVulnerabilityTool: true,
          resolveVulnerabilityAiGateway: true,
          ...glFeatures,
        },
        glAbilities: {
          explainVulnerabilityWithAi: true,
          resolveVulnerabilityWithAi: true,
          ...glAbilities,
        },
      },
    });
  };

  afterEach(() => {
    mockAxios.reset();
    createAlert.mockReset();
  });

  // Resolution Alert
  describe('the vulnerability is no longer detected on the default branch', () => {
    const branchName = 'main';

    beforeEach(() => {
      createWrapper({
        vulnerability: {
          resolvedOnDefaultBranch: true,
          projectDefaultBranch: branchName,
        },
      });
    });

    it('should show the resolution alert component', () => {
      expect(findResolutionAlert().exists()).toBe(true);
    });

    it('should pass down the default branch name', () => {
      expect(findResolutionAlert().props('defaultBranchName')).toEqual(branchName);
    });

    it('should not show the alert component when the vulnerability is resolved', async () => {
      createWrapper({
        vulnerability: {
          state: 'resolved',
        },
      });
      await nextTick();
      const alert = findResolutionAlert();

      expect(alert.exists()).toBe(false);
    });
  });

  describe('status description', () => {
    it('the status description is rendered and passed the correct data', async () => {
      const user = createRandomUser();

      const vulnerability = {
        ...defaultVulnerability,
        state: 'confirmed',
        confirmedById: user.id,
      };

      createWrapper({ vulnerability });

      await waitForPromises();
      expect(findStatusDescription().exists()).toBe(true);
      expect(findStatusDescription().props()).toEqual({
        vulnerability,
        user,
        isLoadingVulnerability: false,
        isLoadingUser: false,
        isStatusBolded: false,
      });
    });

    it.each(vulnerabilityStateEntries)(
      `loads the correct user for the vulnerability state "%s"`,
      async (state) => {
        const user = createRandomUser();
        createWrapper({ vulnerability: { state, [`${state}ById`]: user.id } });

        await waitForPromises();
        expect(mockAxios.history.get).toHaveLength(1);
        expect(findStatusDescription().props('user')).toEqual(user);
      },
    );

    it('does not load a user if there is no user ID', async () => {
      createWrapper({ vulnerability: { state: 'detected' } });

      await waitForPromises();
      expect(mockAxios.history.get).toHaveLength(0);
      expect(findStatusDescription().props('user')).toBeUndefined();
    });

    it('will show an error when the user cannot be loaded', async () => {
      createWrapper({ vulnerability: { state: 'confirmed', confirmedById: 1 } });

      mockAxios.onGet().replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      await waitForPromises();
      expect(createAlert).toHaveBeenCalledTimes(1);
      expect(mockAxios.history.get).toHaveLength(1);
    });

    it('will set the isLoadingUser property correctly when the user is loading and finished loading', async () => {
      const user = createRandomUser();
      createWrapper({ vulnerability: { state: 'confirmed', confirmedById: user.id } });

      expect(findStatusDescription().props('isLoadingUser')).toBe(true);

      await waitForPromises();
      expect(mockAxios.history.get).toHaveLength(1);
      expect(findStatusDescription().props('isLoadingUser')).toBe(false);
    });
  });

  describe('state button', () => {
    it('renders the disabled state button when user can not admin the vulnerability', () => {
      createWrapper({ vulnerability: getVulnerability({ canAdmin: true }) });

      expect(findStateButton().props('disabled')).toBe(false);
    });

    it('renders the enabled state button when user can admin the vulnerability', () => {
      createWrapper({ vulnerability: getVulnerability({ canAdmin: false }) });

      expect(findStateButton().props('disabled')).toBe(true);
    });
  });

  describe.each`
    action       | queryName                          | expected
    ${'dismiss'} | ${'vulnerabilityDismiss'}          | ${'dismissed'}
    ${'confirm'} | ${'vulnerabilityConfirm'}          | ${'confirmed'}
    ${'resolve'} | ${'vulnerabilityResolve'}          | ${'resolved'}
    ${'revert'}  | ${'vulnerabilityRevertToDetected'} | ${'detected'}
  `('state dropdown change', ({ action, queryName, expected }) => {
    describe('when API call is successful', () => {
      beforeEach(() => {
        const apolloProvider = createApolloProvider([
          vulnerabilityStateMutations[action],
          jest.fn().mockResolvedValue(getVulnerabilityStatusMutationResponse(queryName, expected)),
        ]);

        createWrapper({ apolloProvider });
      });

      it('shows the loading icon and passes the correct "loading" prop to the status badge', async () => {
        changeStatus(action);
        await nextTick();

        expect(findGlLoadingIcon().exists()).toBe(true);
        expect(findStatusBadge().props('loading')).toBe(true);
      });

      it(`emits the updated vulnerability properly - ${action}`, async () => {
        changeStatus(action);

        await waitForPromises();
        expect(wrapper.emitted('vulnerability-state-change')[0][0]).toMatchObject({
          state: expected,
        });
      });

      it(`emits an event when the state is changed - ${action}`, async () => {
        changeStatus(action);

        await waitForPromises();
        expect(wrapper.emitted()['vulnerability-state-change']).toHaveLength(1);
      });

      it('does not show the loading icon and passes the correct "loading" prop to the status badge', async () => {
        changeStatus(action);
        await waitForPromises();

        expect(findGlLoadingIcon().exists()).toBe(false);
        expect(findStatusBadge().props('loading')).toBe(false);
      });
    });

    describe('when API call fails', () => {
      beforeEach(() => {
        const apolloProvider = createApolloProvider([
          vulnerabilityStateMutations[action],
          jest.fn().mockRejectedValue({
            data: {
              [queryName]: {
                errors: [{ message: 'Something went wrong' }],
                vulnerability: {},
              },
            },
          }),
        ]);

        createWrapper({ apolloProvider });
      });

      it('shows an error message', async () => {
        changeStatus(action);

        await waitForPromises();
        expect(createAlert).toHaveBeenCalledTimes(1);
      });
    });
  });

  describe('action buttons', () => {
    const clickButton = (eventName) => {
      findSplitButton().vm.$emit(eventName);
      return nextTick();
    };

    describe('split action button', () => {
      it('renders the correct amount of buttons', async () => {
        createWrapper({
          vulnerability: getVulnerability({
            canCreateMergeRequest: true,
            canDownloadPatch: true,
          }),
        });
        await waitForPromises();
        const buttons = findSplitButton().props('buttons');
        expect(buttons).toHaveLength(4);
      });

      it.each`
        index | name                            | tagline
        ${0}  | ${'Resolve with merge request'} | ${'Automatically apply the patch in a new branch'}
        ${1}  | ${'Download patch to resolve'}  | ${'Download the patch to apply it manually'}
        ${2}  | ${'Resolve with merge request'} | ${'Use GitLab Duo AI to generate a merge request with a suggested solution'}
        ${3}  | ${'Explain vulnerability'}      | ${'Use GitLab Duo AI to provide insights about the vulnerability and suggested solutions'}
      `('passes the button for $name at index $index', async ({ index, name, tagline }) => {
        createWrapper({
          vulnerability: getVulnerability({
            canCreateMergeRequest: true,
            canDownloadPatch: true,
          }),
        });
        await waitForPromises();

        const buttons = findSplitButton().props('buttons');
        expect(buttons[index].name).toBe(name);
        expect(buttons[index].tagline).toBe(tagline);
      });

      it('does not display if there are no actions', () => {
        createWrapper({
          vulnerability: getVulnerability({
            canCreateMergeRequest: false,
            canDownloadPatch: false,
          }),
          glAbilities: {
            explainVulnerabilityWithAi: false,
            resolveVulnerabilityWithAi: false,
          },
        });

        expect(findSplitButton().exists()).toBe(false);
      });

      it.each`
        state                      | name
        ${'canCreateMergeRequest'} | ${'Resolve with merge request'}
        ${'canDownloadPatch'}      | ${'Download patch to resolve'}
      `('passes only the $name button if that is the only action', ({ state, name }) => {
        createWrapper({
          vulnerability: getVulnerability({
            [state]: true,
          }),
          glAbilities: {
            explainVulnerabilityWithAi: false,
            resolveVulnerabilityWithAi: false,
          },
        });

        const buttons = findSplitButton().props('buttons');
        expect(buttons).toHaveLength(1);
        expect(buttons[0].name).toBe(name);
      });
    });

    describe('create merge request button', () => {
      beforeEach(() => {
        createWrapper({
          vulnerability: getVulnerability({
            canCreateMergeRequest: true,
          }),
        });
      });

      it('submits correct data for creating a merge request', async () => {
        const vulnerability = {
          ...defaultVulnerability,
          canCreateMergeRequest: true,
          canDownloadPatch: true,
        };

        createWrapper({
          vulnerability: getVulnerability(vulnerability),
          glAbilities: {
            resolveVulnerabilityWithAi: false,
          },
        });
        await waitForPromises();
        const mergeRequestPath = '/group/project/merge_request/123';
        mockAxios.onPost(vulnerability.createMrUrl).reply(HTTP_STATUS_OK, {
          merge_request_path: mergeRequestPath,
          merge_request_links: [{ merge_request_path: mergeRequestPath }],
        });
        await clickButton('create-merge-request');
        await waitForPromises();

        expect(visitUrl).toHaveBeenCalledWith(mergeRequestPath);
        expect(mockAxios.history.post).toHaveLength(1);
        expect(JSON.parse(mockAxios.history.post[0].data)).toMatchObject({
          vulnerability_feedback: {
            feedback_type: FEEDBACK_TYPES.MERGE_REQUEST,
            category: vulnerability.reportType,
            project_fingerprint: vulnerability.projectFingerprint,
            finding_uuid: vulnerability.uuid,
            vulnerability_data: {
              ...convertObjectPropsToSnakeCase(defaultVulnerability),
              category: vulnerability.reportType,
              target_branch: vulnerability.pipeline.sourceBranch,
            },
          },
        });
      });

      it('shows an error message when merge request creation fails', async () => {
        createWrapper({
          vulnerability: getVulnerability({
            canCreateMergeRequest: true,
            canDownloadPatch: true,
          }),
        });
        await waitForPromises();
        mockAxios
          .onPost(defaultVulnerability.create_mr_url)
          .reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
        await clickButton('create-merge-request');
        await waitForPromises();

        expect(mockAxios.history.post).toHaveLength(1);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was an error creating the merge request. Please try again.',
        });
      });
    });

    describe('can download patch button', () => {
      beforeEach(() => {
        createWrapper({
          vulnerability: getVulnerability({
            canDownloadPatch: true,
          }),
        });
      });

      it('calls download utility correctly', async () => {
        createWrapper({
          vulnerability: getVulnerability({
            canCreateMergeRequest: true,
            canDownloadPatch: true,
          }),
        });
        await waitForPromises();
        await clickButton('download-patch');

        expect(download).toHaveBeenCalledWith({
          fileData: diff,
          fileName: `remediation.patch`,
        });
      });
    });

    describe('resolve with AI button', () => {
      let mockSubscription;
      let subscriptionSpy;

      const findResolveWithAIButton = () => findSplitButton().props('buttons')[0];

      const createWrapperWithAiApollo = ({
        mutationResponse = MUTATION_AI_ACTION_DEFAULT_RESPONSE,
      } = {}) => {
        mockSubscription = createMockSubscription();
        subscriptionSpy = jest.fn().mockReturnValue(mockSubscription);

        const apolloProvider = createMockApollo([[aiResolveVulnerability, mutationResponse]]);
        apolloProvider.defaultClient.setRequestHandler(aiResponseSubscription, subscriptionSpy);

        createWrapper({
          vulnerability: getVulnerability(),
          apolloProvider,
        });

        return waitForPromises();
      };

      const createWrapperAndClickButton = (params) => {
        createWrapperWithAiApollo(params);
        findSplitButton().vm.$emit('start-subscription');
        return nextTick();
      };

      const sendSubscriptionMessage = (aiCompletionResponse) => {
        mockSubscription.next({ data: { aiCompletionResponse } });
        return waitForPromises();
      };

      // When the subscription is ready, a null aiCompletionResponse is sent
      const waitForSubscriptionToBeReady = () => sendSubscriptionMessage(null);

      beforeEach(() => {
        gon.current_user_id = 1;
      });

      it('passes the category and tanuki icon', () => {
        createWrapper({
          vulnerability: getVulnerability(),
        });

        expect(findResolveWithAIButton()).toMatchObject({
          icon: 'tanuki-ai',
          category: 'primary',
        });
      });

      // Note: when the `resolveVulnerability` is removed, these tests can be deleted as well
      it('does not pass the experimental badge or tooltip', () => {
        createWrapper({
          vulnerability: getVulnerability(),
        });

        expect(findResolveWithAIButton()).not.toHaveProperty('badge');
        expect(findResolveWithAIButton()).not.toHaveProperty('tooltip');
      });

      it('continues to show the loading state into the redirect call', async () => {
        await createWrapperWithAiApollo();

        const resolveAIButton = findSplitButton();
        expect(resolveAIButton.props('loading')).toBe(false);

        await clickButton('start-subscription');
        expect(resolveAIButton.props('loading')).toBe(true);

        await waitForSubscriptionToBeReady();
        expect(resolveAIButton.props('loading')).toBe(true);

        await sendSubscriptionMessage(MOCK_SUBSCRIPTION_RESPONSE);
        expect(resolveAIButton.props('loading')).toBe(true);
        expect(visitUrl).toHaveBeenCalledTimes(1);
      });

      it('redirects after it receives the AI response', async () => {
        await createWrapperAndClickButton();
        await waitForSubscriptionToBeReady();
        expect(visitUrl).not.toHaveBeenCalled();

        await sendSubscriptionMessage(MOCK_SUBSCRIPTION_RESPONSE);
        expect(visitUrl).toHaveBeenCalledTimes(1);
        expect(visitUrl).toHaveBeenCalledWith(MOCK_SUBSCRIPTION_RESPONSE.content);
      });

      it('calls the mutation with the correct input', async () => {
        await createWrapperAndClickButton();
        await waitForSubscriptionToBeReady();

        expect(MUTATION_AI_ACTION_DEFAULT_RESPONSE).toHaveBeenCalledWith({
          resourceId: 'gid://gitlab/Vulnerability/1',
          clientSubscriptionId: CLIENT_SUBSCRIPTION_ID,
        });
      });

      it.each`
        type                    | mutationResponse                       | subscriptionMessage               | expectedError
        ${'mutation global'}    | ${MUTATION_AI_ACTION_GLOBAL_ERROR}     | ${null}                           | ${'mutation global error'}
        ${'mutation ai action'} | ${MUTATION_AI_ACTION_ERROR}            | ${null}                           | ${'mutation ai action error'}
        ${'subscription'}       | ${MUTATION_AI_ACTION_DEFAULT_RESPONSE} | ${AI_SUBSCRIPTION_ERROR_RESPONSE} | ${'subscription error'}
      `(
        'unsubscribes and shows only an error when there is a $type error',
        async ({ mutationResponse, subscriptionMessage, expectedError }) => {
          await createWrapperAndClickButton({ mutationResponse });
          await waitForSubscriptionToBeReady();
          await sendSubscriptionMessage(subscriptionMessage);

          expect(findSplitButton().props('loading')).toBe(false);
          expect(visitUrl).not.toHaveBeenCalled();
          expect(createAlert.mock.calls[0][0].message.toString()).toContain(expectedError);
        },
      );

      it('starts the subscription, waits for the subscription to be ready, then runs the mutation', async () => {
        await createWrapperWithAiApollo({
          canCreateMergeRequest: true,
          canDownloadPatch: true,
        });
        await clickButton('start-subscription');
        expect(subscriptionSpy).toHaveBeenCalled();
        expect(MUTATION_AI_ACTION_DEFAULT_RESPONSE).not.toHaveBeenCalled();

        await waitForSubscriptionToBeReady();
        expect(MUTATION_AI_ACTION_DEFAULT_RESPONSE).toHaveBeenCalled();
      });
    });

    describe('explain with AI button', () => {
      let chatMutationHandlerMock;

      const findExplainWithAIButton = () => findSplitButton().props('buttons')[1];

      beforeEach(() => {
        chatMutationHandlerMock = jest.fn().mockResolvedValue(MOCK_TANUKI_BOT_MUTATATION_RES);

        const apolloProvider = createApolloProvider([chatMutation, chatMutationHandlerMock]);

        createWrapper({
          vulnerability: getVulnerability(),
          apolloProvider,
        });
      });

      it('receives the correct button props', () => {
        expect(findExplainWithAIButton()).toMatchObject({
          icon: 'tanuki-ai',
          category: 'primary',
          name: 'Explain vulnerability',
          tagline:
            'Use GitLab Duo AI to provide insights about the vulnerability and suggested solutions',
        });
      });

      it('opens the global DuoChat drawer when clicked', async () => {
        expect(helpCenterState.showTanukiBotChatDrawer).toBe(false);

        await clickButton('explain-vulnerability');

        expect(helpCenterState.showTanukiBotChatDrawer).toBe(true);
      });

      it('calls the correct mutation with the correct parameters when clicked', async () => {
        await clickButton('explain-vulnerability');
        await waitForPromises();

        expect(chatMutationHandlerMock).toHaveBeenCalledWith({
          question: '/vulnerability_explain',
          resourceId: `gid://gitlab/Vulnerability/${defaultVulnerability.id}`,
        });
      });
    });
  });

  describe('when user does not have "resolveVulnerabilityAi" ability', () => {
    it('does not pass the Resolve with AI button', async () => {
      createWrapper({
        glFeatures: {
          resolveVulnerabilityAiGateway: false,
          resolveVulnerability: false,
        },
        glAbilities: {
          resolveVulnerabilityWithAi: false,
        },
        vulnerability: getVulnerability({
          canCreateMergeRequest: true,
          canDownloadPatch: true,
        }),
      });
      await waitForPromises();

      expect(findSplitButton().exists()).toBe(true);
      const buttons = findSplitButton().props('buttons');
      expect(buttons).toHaveLength(3);
      expect(buttons[0].name).toBe('Resolve with merge request');
      expect(buttons[1].name).toBe('Download patch to resolve');
      expect(buttons[2].name).toBe('Explain vulnerability');
    });
  });

  describe('when using experimental "Resolve with AI" (deprecated)', () => {
    it('passes the experiment badge, tooltip, category, and tanuki icon', () => {
      createWrapper({
        glFeatures: {
          explainVulnerabilityTool: false,
          resolveVulnerabilityAiGateway: false,
          resolveVulnerability: true,
        },
        vulnerability: getVulnerability(),
      });

      const buttons = findSplitButton().props('buttons');
      expect(buttons[0]).toMatchObject({
        badge: 'Experiment',
        tooltip:
          'This is an experiment feature that uses AI to provide recommendations for resolving this vulnerability. Use this feature with caution.',
        icon: 'tanuki-ai',
        category: 'primary',
      });
    });
  });

  describe('when the "explainVulnerabilityTool" feature flag is disabled', () => {
    it('does not show the "Explain with AI" button', async () => {
      createWrapper({
        glFeatures: {
          explainVulnerabilityTool: false,
        },
        vulnerability: getVulnerability(),
      });
      await waitForPromises();

      const buttons = findSplitButton().props('buttons');
      expect(buttons).toHaveLength(1);
      expect(buttons[0].name).not.toBe('Explain with AI');
    });
  });
});
