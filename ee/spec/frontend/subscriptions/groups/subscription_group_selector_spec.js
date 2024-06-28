import { nextTick } from 'vue';
import {
  GlAccordion,
  GlAccordionItem,
  GlCollapsibleListbox,
  GlButton,
  GlFormGroup,
} from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import Component from 'ee/subscriptions/groups/new/components/subscription_group_selector.vue';
import { stubComponent } from 'helpers/stub_component';
import { visitUrl } from '~/lib/utils/url_utility';

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));

describe('SubscriptionGroupSelector component', () => {
  let wrapper;

  const eligibleGroups = [
    { id: 1, name: 'Group one' },
    { id: 2, name: 'Group two' },
    { id: 3, name: 'Group three' },
    { id: 4, name: 'Group four' },
  ];

  const plansData = {
    code: 'premium',
    id: 'premium-plan-id',
    purchase_link: { href: 'path/to/purchase?plan_id=premium-plan-id' },
  };

  const rootUrl = 'https://gitlab.com/';

  const defaultPropsData = { eligibleGroups, plansData, rootUrl };

  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findGroupSelectionFormGroup = () => wrapper.findByTestId('group-selector');
  const findContinueButton = () => wrapper.findComponent(GlButton);
  const findHeader = () => wrapper.find('h2');

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(Component, {
      propsData: {
        ...defaultPropsData,
        ...propsData,
      },
      stubs: {
        GlFormGroup: stubComponent(GlFormGroup, {
          props: ['state', 'invalidFeedback'],
        }),
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  describe('title', () => {
    it('renders title correctly for premium plan', () => {
      expect(findHeader().text()).toBe(`Select a group for your Premium subscription`);
    });

    it('renders title correctly for ultimate plan', () => {
      createComponent({ plansData: { ...plansData, code: 'ultimate' } });

      expect(findHeader().text()).toBe(`Select a group for your Ultimate subscription`);
    });

    it('renders title correctly for other plans', () => {
      createComponent({ plansData: { ...plansData, code: 'non-premium', name: 'SaaS' } });

      expect(findHeader().text()).toBe(`Select a group for your SaaS subscription`);
    });
  });

  describe('group selection', () => {
    it('renders collapsible list box with correct options', () => {
      const expectedResult = eligibleGroups.map(({ id, name }) => ({ value: id, text: name }));

      expect(findCollapsibleListbox().props().items).toEqual(expectedResult);
    });

    it('renders collapsible list box with correct variant', () => {
      expect(findCollapsibleListbox().props('variant')).toBe('default');
    });

    it('does not show validation message on initial render', () => {
      expect(findGroupSelectionFormGroup().props('state')).toBe(true);
    });

    it('shows validation message when no group is selected', async () => {
      findContinueButton().vm.$emit('click');

      await nextTick();

      expect(findGroupSelectionFormGroup().props('state')).toBe(false);
      expect(findGroupSelectionFormGroup().props('invalidFeedback')).toBe(
        'Select a group for your subscription',
      );
      expect(findCollapsibleListbox().props('variant')).toBe('danger');
    });

    it('does not redirect when no group is selected', async () => {
      findContinueButton().vm.$emit('click');

      await nextTick();

      expect(visitUrl).not.toHaveBeenCalled();
    });

    it('redirects to purchase flow when a valid group is selected', async () => {
      const selectedGroupId = eligibleGroups[2].id;
      const expectedUrl = `${plansData.purchase_link.href}&gl_namespace_id=${selectedGroupId}`;

      findCollapsibleListbox().vm.$emit('select', selectedGroupId);
      findContinueButton().vm.$emit('click');

      await nextTick();

      expect(visitUrl).toHaveBeenCalledWith(expectedUrl);
    });

    it('reports an error when no purchase link URL is provided', async () => {
      const plansDataProp = { ...plansData, purchase_link: null };
      const error = `Missing purchase link for plan ${JSON.stringify(plansDataProp)}`;

      createComponent({ plansData: plansDataProp });

      findCollapsibleListbox().vm.$emit('select', eligibleGroups[2].id);
      findContinueButton().vm.$emit('click');

      await nextTick();

      expect(visitUrl).not.toHaveBeenCalled();
      expect(Sentry.captureException).toHaveBeenCalledWith(error, {
        tags: { vue_component: 'SubscriptionGroupSelector' },
      });
    });
  });

  describe('accordion', () => {
    it('renders accordion', () => {
      expect(findAccordion().props('headerLevel')).toBe(3);
    });

    it('renders accordion item', () => {
      const accordionItem = findAccordionItem();

      expect(accordionItem.props('title')).toBe(`Why can't I find my group?`);
      expect(accordionItem.text()).toContain(
        `Your group will only be displayed in the list above if:`,
      );
      expect(accordionItem.text()).toContain(`You're assigned the Owner role of the group`);
      expect(accordionItem.text()).toContain(`The group is a top-level group on a Free tier`);
    });
  });
});
