import * as Sentry from '@sentry/browser';
import { GlAlert, GlLink, GlToggle, GlCard, GlSkeletonLoader } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import {
  TRACK_TOGGLE_TRAINING_PROVIDER_ACTION,
  TRACK_TOGGLE_TRAINING_PROVIDER_LABEL,
  TRACK_PROVIDER_LEARN_MORE_CLICK_ACTION,
  TRACK_PROVIDER_LEARN_MORE_CLICK_LABEL,
} from '~/security_configuration/constants';
import TrainingProviderList from '~/security_configuration/components/training_provider_list.vue';
import { updateSecurityTrainingOptimisticResponse } from '~/security_configuration/graphql/cache_utils';
import securityTrainingProvidersQuery from '~/security_configuration/graphql/security_training_providers.query.graphql';
import configureSecurityTrainingProvidersMutation from '~/security_configuration/graphql/configure_security_training_providers.mutation.graphql';
import dismissUserCalloutMutation from '~/graphql_shared/mutations/dismiss_user_callout.mutation.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import {
  dismissUserCalloutResponse,
  dismissUserCalloutErrorResponse,
  getSecurityTrainingProvidersData,
  updateSecurityTrainingProvidersResponse,
  updateSecurityTrainingProvidersErrorResponse,
  testProjectPath,
  testProviderIds,
  testProviderName,
  tempProviderLogos,
} from '../mock_data';

Vue.use(VueApollo);

const TEST_TRAINING_PROVIDERS_ALL_DISABLED = getSecurityTrainingProvidersData();
const TEST_TRAINING_PROVIDERS_FIRST_ENABLED = getSecurityTrainingProvidersData({
  providerOverrides: { first: { isEnabled: true, isPrimary: true } },
});
const TEST_TRAINING_PROVIDERS_ALL_ENABLED = getSecurityTrainingProvidersData({
  providerOverrides: {
    first: { isEnabled: true, isPrimary: true },
    second: { isEnabled: true, isPrimary: false },
    third: { isEnabled: true, isPrimary: false },
  },
});
const TEST_TRAINING_PROVIDERS_DEFAULT = TEST_TRAINING_PROVIDERS_ALL_DISABLED;

describe('TrainingProviderList component', () => {
  let wrapper;
  let apolloProvider;

  const createApolloProvider = ({ handlers = [] } = {}) => {
    const defaultHandlers = [
      [
        securityTrainingProvidersQuery,
        jest.fn().mockResolvedValue(TEST_TRAINING_PROVIDERS_DEFAULT.response),
      ],
      [
        configureSecurityTrainingProvidersMutation,
        jest.fn().mockResolvedValue(updateSecurityTrainingProvidersResponse),
      ],
    ];

    // make sure we don't have any duplicate handlers to avoid 'Request handler already defined for query` errors
    const mergedHandlers = [...new Map([...defaultHandlers, ...handlers])];

    apolloProvider = createMockApollo(mergedHandlers);
  };

  const createComponent = () => {
    wrapper = shallowMountExtended(TrainingProviderList, {
      provide: {
        projectFullPath: testProjectPath,
      },
      apolloProvider,
    });
  };

  const waitForQueryToBeLoaded = () => waitForPromises();
  const waitForMutationToBeLoaded = waitForQueryToBeLoaded;

  const findCards = () => wrapper.findAllComponents(GlCard);
  const findLinks = () => wrapper.findAllComponents(GlLink);
  const findToggles = () => wrapper.findAllComponents(GlToggle);
  const findFirstToggle = () => findToggles().at(0);
  const findPrimaryProviderRadios = () => wrapper.findAllByTestId('primary-provider-radio');
  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findErrorAlert = () => wrapper.findComponent(GlAlert);
  const findLogos = () => wrapper.findAll('img');

  const toggleFirstProvider = () => findFirstToggle().vm.$emit('change', testProviderIds[0]);

  afterEach(() => {
    wrapper.destroy();
    apolloProvider = null;
  });

  describe('when loading', () => {
    beforeEach(() => {
      const pendingHandler = () => new Promise(() => {});

      createApolloProvider({
        handlers: [[securityTrainingProvidersQuery, pendingHandler]],
      });
      createComponent();
    });

    it('shows the loader', () => {
      expect(findLoader().exists()).toBe(true);
    });

    it('does not show the cards', () => {
      expect(findCards().exists()).toBe(false);
    });
  });

  describe('with a successful response', () => {
    beforeEach(() => {
      createApolloProvider({
        handlers: [
          [dismissUserCalloutMutation, jest.fn().mockResolvedValue(dismissUserCalloutResponse)],
        ],
        resolvers: {
          Mutation: {
            configureSecurityTrainingProviders: () => ({
              errors: [],
              TEST_TRAINING_PROVIDERS_DEFAULT: [],
            }),
          },
        },
      });

      createComponent();
    });

    describe('basic structure', () => {
      beforeEach(async () => {
        await waitForQueryToBeLoaded();
      });

      it('renders correct amount of cards', () => {
        expect(findCards()).toHaveLength(TEST_TRAINING_PROVIDERS_DEFAULT.data.length);
      });

      TEST_TRAINING_PROVIDERS_DEFAULT.data.forEach(
        ({ name, description, url, isEnabled }, index) => {
          it(`shows the name for card ${index}`, () => {
            expect(findCards().at(index).text()).toContain(name);
          });

          it(`shows the description for card ${index}`, () => {
            expect(findCards().at(index).text()).toContain(description);
          });

          it(`shows the learn more link for card ${index}`, () => {
            expect(findLinks().at(index).attributes()).toEqual({
              target: '_blank',
              href: url,
            });
          });

          it(`shows the toggle with the correct value for card ${index}`, () => {
            expect(findToggles().at(index).props('value')).toEqual(isEnabled);
          });

          it(`shows a radio button to select the provider as primary within card ${index}`, () => {
            const primaryProviderRadioForCurrentCard = findPrimaryProviderRadios().at(index);

            // if the given provider is not enabled it should not be possible select it as primary
            expect(primaryProviderRadioForCurrentCard.find('input').attributes('disabled')).toBe(
              isEnabled ? undefined : 'disabled',
            );

            expect(primaryProviderRadioForCurrentCard.text()).toBe(
              TrainingProviderList.i18n.primaryTraining,
            );
          });

          it('does not show loader when query is populated', () => {
            expect(findLoader().exists()).toBe(false);
          });
        },
      );
    });

    describe('provider logo', () => {
      beforeEach(async () => {
        wrapper.vm.$options.TEMP_PROVIDER_LOGOS = tempProviderLogos;
        await waitForQueryToBeLoaded();
      });

      const providerIndexArray = [0, 1];

      it.each(providerIndexArray)('displays the correct width for provider %s', (provider) => {
        expect(findLogos().at(provider).attributes('width')).toBe('18');
      });

      it.each(providerIndexArray)('has a11y decorative attribute for provider %s', (provider) => {
        expect(findLogos().at(provider).attributes('role')).toBe('presentation');
      });

      it.each(providerIndexArray)('displays the correct svg path for provider %s', (provider) => {
        expect(findLogos().at(provider).attributes('src')).toBe(
          tempProviderLogos[testProviderName[provider]].svg,
        );
      });
    });

    describe('storing training provider settings', () => {
      beforeEach(async () => {
        jest.spyOn(apolloProvider.defaultClient, 'mutate');

        await waitForQueryToBeLoaded();

        await toggleFirstProvider();
      });

      it('calls mutation when toggle is changed', () => {
        expect(apolloProvider.defaultClient.mutate).toHaveBeenCalledWith(
          expect.objectContaining({
            mutation: configureSecurityTrainingProvidersMutation,
            variables: {
              input: {
                providerId: testProviderIds[0],
                isEnabled: true,
                isPrimary: true,
                projectPath: testProjectPath,
              },
            },
          }),
        );
      });

      it('returns an optimistic response when calling the mutation', () => {
        const optimisticResponse = updateSecurityTrainingOptimisticResponse({
          id: TEST_TRAINING_PROVIDERS_DEFAULT.data[0].id,
          isEnabled: true,
          isPrimary: true,
        });

        expect(apolloProvider.defaultClient.mutate).toHaveBeenCalledWith(
          expect.objectContaining({
            optimisticResponse,
          }),
        );
      });

      it('dismisses the callout when the feature gets first enabled', async () => {
        // wait for configuration update mutation to complete
        await waitForMutationToBeLoaded();

        // both the config and dismiss mutations have been called
        expect(apolloProvider.defaultClient.mutate).toHaveBeenCalledTimes(2);
        expect(apolloProvider.defaultClient.mutate).toHaveBeenNthCalledWith(
          2,
          expect.objectContaining({
            mutation: dismissUserCalloutMutation,
            variables: {
              input: {
                featureName: 'security_training_feature_promotion',
              },
            },
          }),
        );

        toggleFirstProvider();
        await waitForMutationToBeLoaded();

        // the config mutation has been called again but not the dismiss mutation
        expect(apolloProvider.defaultClient.mutate).toHaveBeenCalledTimes(3);
        expect(apolloProvider.defaultClient.mutate).toHaveBeenNthCalledWith(
          3,
          expect.objectContaining({
            mutation: configureSecurityTrainingProvidersMutation,
          }),
        );
      });
    });

    describe('metrics', () => {
      let trackingSpy;

      beforeEach(() => {
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      afterEach(() => {
        unmockTracking();
      });

      it('tracks when a provider gets toggled', () => {
        expect(trackingSpy).not.toHaveBeenCalled();

        toggleFirstProvider();

        // Note: Ideally we also want to test that the tracking event is called correctly when a
        // provider gets disabled, but that's a bit tricky to do with the current implementation
        // Once https://gitlab.com/gitlab-org/gitlab/-/issues/348985 and https://gitlab.com/gitlab-org/gitlab/-/merge_requests/79492
        // are merged this will be much easer to do and should be tackled then.
        expect(trackingSpy).toHaveBeenCalledWith(undefined, TRACK_TOGGLE_TRAINING_PROVIDER_ACTION, {
          property: TEST_TRAINING_PROVIDERS_DEFAULT.data[0].id,
          label: TRACK_TOGGLE_TRAINING_PROVIDER_LABEL,
          extra: {
            providerIsEnabled: true,
          },
        });
      });

      it(`tracks when a provider's "Learn more" link is clicked`, () => {
        const firstProviderLink = findLinks().at(0);
        const [{ id: firstProviderId }] = TEST_TRAINING_PROVIDERS_DEFAULT.data;

        expect(trackingSpy).not.toHaveBeenCalled();

        firstProviderLink.vm.$emit('click');

        expect(trackingSpy).toHaveBeenCalledWith(
          undefined,
          TRACK_PROVIDER_LEARN_MORE_CLICK_ACTION,
          {
            label: TRACK_PROVIDER_LEARN_MORE_CLICK_LABEL,
            property: firstProviderId,
          },
        );
      });
    });
  });

  describe('primary provider settings', () => {
    it.each`
      description                                                                                 | initialProviderData                               | expectedMutationInput
      ${'sets the provider to be non-primary when it gets disabled'}                              | ${TEST_TRAINING_PROVIDERS_FIRST_ENABLED.response} | ${{ providerId: TEST_TRAINING_PROVIDERS_FIRST_ENABLED.data[0].id, isEnabled: false, isPrimary: false }}
      ${'sets a provider to be primary when it is the only one enabled'}                          | ${TEST_TRAINING_PROVIDERS_ALL_DISABLED.response}  | ${{ providerId: TEST_TRAINING_PROVIDERS_ALL_DISABLED.data[0].id, isEnabled: true, isPrimary: true }}
      ${'sets the first other enabled provider to be primary when the primary one gets disabled'} | ${TEST_TRAINING_PROVIDERS_ALL_ENABLED.response}   | ${{ providerId: TEST_TRAINING_PROVIDERS_ALL_ENABLED.data[1].id, isEnabled: true, isPrimary: true }}
    `('$description', async ({ initialProviderData, expectedMutationInput }) => {
      createApolloProvider({
        handlers: [
          [securityTrainingProvidersQuery, jest.fn().mockResolvedValue(initialProviderData)],
        ],
      });
      jest.spyOn(apolloProvider.defaultClient, 'mutate');
      createComponent();

      await waitForQueryToBeLoaded();
      await toggleFirstProvider();

      expect(apolloProvider.defaultClient.mutate).toHaveBeenNthCalledWith(
        1,
        expect.objectContaining({
          variables: {
            input: expect.objectContaining({
              ...expectedMutationInput,
            }),
          },
        }),
      );
    });
  });

  describe('with errors', () => {
    const expectErrorAlertToExist = () => {
      expect(findErrorAlert().props()).toMatchObject({
        dismissible: false,
        variant: 'danger',
      });
    };

    describe('when fetching training providers', () => {
      beforeEach(async () => {
        createApolloProvider({
          handlers: [[securityTrainingProvidersQuery, jest.fn().mockRejectedValue()]],
        });
        createComponent();

        await waitForQueryToBeLoaded();
      });

      it('shows an non-dismissible error alert', () => {
        expectErrorAlertToExist();
      });

      it('shows an error description', () => {
        expect(findErrorAlert().text()).toBe(TrainingProviderList.i18n.providerQueryErrorMessage);
      });
    });

    describe('when storing training provider configurations', () => {
      beforeEach(async () => {
        createApolloProvider({
          handlers: [
            [
              configureSecurityTrainingProvidersMutation,
              jest.fn().mockReturnValue(updateSecurityTrainingProvidersErrorResponse),
            ],
          ],
        });
        createComponent();

        await waitForQueryToBeLoaded();
        toggleFirstProvider();
        await waitForMutationToBeLoaded();
      });

      it('shows an non-dismissible error alert', () => {
        expectErrorAlertToExist();
      });

      it('shows an error description', () => {
        expect(findErrorAlert().text()).toBe(TrainingProviderList.i18n.configMutationErrorMessage);
      });
    });

    describe.each`
      errorType          | mutationHandler
      ${'backend error'} | ${jest.fn().mockReturnValue(dismissUserCalloutErrorResponse)}
      ${'network error'} | ${jest.fn().mockRejectedValue()}
    `('when dismissing the callout and a "$errorType" happens', ({ mutationHandler }) => {
      beforeEach(async () => {
        jest.spyOn(Sentry, 'captureException').mockImplementation();

        createApolloProvider({
          handlers: [[dismissUserCalloutMutation, mutationHandler]],
          resolvers: {
            Mutation: {
              configureSecurityTrainingProviders: () => ({
                errors: [],
                securityTrainingProviders: [],
              }),
            },
          },
        });
        createComponent();

        await waitForQueryToBeLoaded();
        toggleFirstProvider();
      });

      it('logs the error to sentry', async () => {
        expect(Sentry.captureException).not.toHaveBeenCalled();

        await waitForMutationToBeLoaded();

        expect(Sentry.captureException).toHaveBeenCalled();
      });
    });
  });
});
