import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlLoadingIcon, GlSprintf } from '@gitlab/ui';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import initializeProductAnalyticsMutation from 'ee/product_analytics/graphql/mutations/initialize_product_analytics.mutation.graphql';
import ProviderSelectionView from 'ee/product_analytics/onboarding/components/providers/provider_selection_view.vue';
import GitLabManagedProviderCard from 'ee/product_analytics/onboarding/components/providers/gitlab_managed_provider_card.vue';
import SelfManagedProviderCard from 'ee/product_analytics/onboarding/components/providers/self_managed_provider_card.vue';

import { createInstanceResponse } from '../../../mock_data';

Vue.use(VueApollo);

describe('ProviderSelectionView', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let windowOpenSpy;

  const fatalError = new Error('GraphQL networkError');
  const apiErrorMsg = 'Product analytics initialization is already complete';
  const mockApolloSuccess = jest.fn().mockResolvedValue(createInstanceResponse([]));
  const mockApolloApiError = jest.fn().mockResolvedValue(createInstanceResponse([apiErrorMsg]));
  const mockApolloFatalError = jest.fn().mockRejectedValue(fatalError);

  const findGlEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findSelfManagedProviderCard = () => wrapper.findComponent(SelfManagedProviderCard);
  const findGitLabManagedProviderCard = () => wrapper.findComponent(GitLabManagedProviderCard);

  const createWrapper = (apolloMock = mockApolloSuccess) => {
    windowOpenSpy = jest.spyOn(window, 'open').mockImplementation(() => {});
    wrapper = shallowMountExtended(ProviderSelectionView, {
      apolloProvider: createMockApollo([[initializeProductAnalyticsMutation, apolloMock]]),
      propsData: {
        loadingInstance: false,
      },
      provide: {
        analyticsSettingsPath: '/settings/analytics',
        namespaceFullPath: 'group/project',
        chartEmptyStateIllustrationPath: '/path/to/illustration.svg',
        projectLevelAnalyticsProviderSettings: {},
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('default behaviour', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should render a description', () => {
      expect(wrapper.text()).toContain(
        'Set up Product Analytics to track how your product is performing. Combine analytics with your GitLab data to better understand where you can improve your product and development processes.',
      );
    });

    it('should offer provider selection', () => {
      expect(wrapper.text()).toContain('Select an option');
      expect(findSelfManagedProviderCard().exists()).toBe(true);
      expect(findGitLabManagedProviderCard().exists()).toBe(true);
    });

    it('does not render the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  describe.each`
    scenario            | findComponent
    ${'self-managed'}   | ${findSelfManagedProviderCard}
    ${'GitLab-managed'} | ${findGitLabManagedProviderCard}
  `('$scenario', ({ findComponent }) => {
    describe('when component emits "confirm" event', () => {
      describe('when initialization succeeds', () => {
        beforeEach(() => {
          createWrapper();
          findComponent().vm.$emit('confirm');
          return waitForPromises();
        });

        it('should emit `initialized`', () => {
          expect(wrapper.emitted('initialized')).toStrictEqual([[]]);
        });

        it('should show loading state', () => {
          expect(findGlEmptyState().props()).toMatchObject({
            title: 'Creating your product analytics instance...',
            svgPath: '/path/to/illustration.svg',
          });
          expect(findLoadingIcon().exists()).toBe(true);
        });
      });

      describe('when initialize fails', () => {
        describe.each`
          type       | error                     | apolloMock
          ${'api'}   | ${new Error(apiErrorMsg)} | ${mockApolloApiError}
          ${'fatal'} | ${fatalError}             | ${mockApolloFatalError}
        `('with a $type error', ({ error, apolloMock }) => {
          beforeEach(() => {
            createWrapper(apolloMock);
            findComponent().vm.$emit('confirm');
            return waitForPromises();
          });

          it('does not render the loading icon', () => {
            expect(findLoadingIcon().exists()).toBe(false);
          });

          it('emits the captured error', () => {
            expect(wrapper.emitted('error')).toEqual([[error]]);
          });
        });
      });
    });

    describe('when component emits "open-settings" event', () => {
      beforeEach(() => {
        createWrapper();
        findComponent().vm.$emit('open-settings');
        return waitForPromises();
      });

      it('should redirect the user to settings', () => {
        expect(windowOpenSpy).toHaveBeenCalledWith(
          '/settings/analytics#js-analytics-data-sources',
          '_blank',
        );
      });
    });
  });
});
