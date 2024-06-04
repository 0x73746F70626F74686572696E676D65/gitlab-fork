import OnboardingListItem from 'ee/product_analytics/onboarding/components/onboarding_list_item.vue';
import OnboardingState from 'ee/product_analytics/onboarding/components/onboarding_state.vue';
import AnalyticsFeatureListItem from 'ee/analytics/analytics_dashboards/components/list/feature_list_item.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import {
  STATE_CREATE_INSTANCE,
  STATE_LOADING_INSTANCE,
  STATE_WAITING_FOR_EVENTS,
} from 'ee/product_analytics/onboarding/constants';

import { TEST_PROJECT_FULL_PATH } from '../../mock_data';

describe('OnboardingListItem', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findListItem = () => wrapper.findComponent(AnalyticsFeatureListItem);
  const findState = () => wrapper.findComponent(OnboardingState);

  const createWrapper = (state, provide = {}) => {
    wrapper = shallowMountExtended(OnboardingListItem, {
      provide: {
        canConfigureProjectSettings: true,
        namespaceFullPath: TEST_PROJECT_FULL_PATH,
        ...provide,
      },
    });

    return findState().vm.$emit('change', state);
  };

  describe('default behaviour', () => {
    beforeEach(() => {
      return createWrapper(STATE_CREATE_INSTANCE);
    });

    it('renders the list item', () => {
      expect(findListItem().props()).toMatchObject({
        title: 'Product Analytics',
        description:
          'Track the performance of your product, and optimize your product and development processes.',
        badgeText: null,
        badgePopoverText: null,
        to: 'product-analytics-onboarding',
      });
    });

    describe('and the state is complete', () => {
      beforeEach(() => {
        return findState().vm.$emit('complete');
      });

      it('emits the complete event', () => {
        expect(wrapper.emitted('complete')).toEqual([[]]);
      });
    });

    describe('and the state emitted an error', () => {
      const error = new Error('error');

      beforeEach(() => {
        return findState().vm.$emit('error', error);
      });

      it('emits an error event with a message', () => {
        expect(wrapper.emitted('error')).toEqual([
          [error, true, 'An error occurred while fetching data. Refresh the page to try again.'],
        ]);
      });
    });
  });

  describe('badge text', () => {
    it.each`
      state                       | badgeText               | badgePopoverText
      ${STATE_WAITING_FOR_EVENTS} | ${'Waiting for events'} | ${'An analytics provider has been successfully created, but it has not received any events yet. To continue with the setup, instrument your application and start sending events.'}
      ${STATE_LOADING_INSTANCE}   | ${'Loading instance'}   | ${'The system is creating your analytics provider. In the meantime, you can instrument your application.'}
    `(
      'renders "$badgeText" with popover "$badgePopoverText" when the state is "$state"',
      async ({ state, badgeText, badgePopoverText }) => {
        await createWrapper(state);

        expect(findListItem().props()).toMatchObject(
          expect.objectContaining({
            badgeText,
            badgePopoverText,
          }),
        );
      },
    );
  });

  describe('action text', () => {
    it.each`
      state                       | actionText
      ${STATE_CREATE_INSTANCE}    | ${'Set up'}
      ${STATE_WAITING_FOR_EVENTS} | ${'Continue set up'}
      ${STATE_LOADING_INSTANCE}   | ${'Continue set up'}
    `(
      'renders action text "$actionText" when the state is "$state"',
      async ({ state, actionText }) => {
        await createWrapper(state);

        expect(findListItem().props('actionText')).toBe(actionText);
      },
    );
  });

  describe('when user does not have required permissions', () => {
    beforeEach(() => {
      createWrapper(STATE_CREATE_INSTANCE, {
        canConfigureProjectSettings: false,
      });
    });

    it('does disables the setup button', () => {
      expect(findListItem().props('actionDisabled')).toBe(true);
    });

    it('renders a badge informing the user they have insufficient permissions', () => {
      expect(findListItem().props()).toMatchObject(
        expect.objectContaining({
          badgeText: 'Additional permissions required',
          badgePopoverText:
            'Contact the GitLab administrator or project maintainer to onboard this project with product analytics. %{linkStart}Learn more%{linkEnd}.',
          badgePopoverLink: '/help/user/product_analytics#onboard-a-gitlab-project',
        }),
      );
    });
  });
});
