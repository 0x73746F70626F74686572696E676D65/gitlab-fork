import { nextTick } from 'vue';
import { GlAccordion, GlAccordionItem, GlAlert, GlCollapsibleListbox, GlForm } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import Component from 'ee/subscriptions/groups/new/components/subscription_group_selector.vue';
import { stubComponent } from 'helpers/stub_component';
import { visitUrl } from '~/lib/utils/url_utility';
import waitForPromises from 'helpers/wait_for_promises';
import { getGroupPathAvailability } from '~/rest_api';
import { subscriptionsCreateGroup } from 'ee_else_ce/api/groups_api';

jest.mock('ee_else_ce/api/groups_api');
jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));
jest.mock('~/rest_api', () => ({
  getGroupPathAvailability: jest.fn(),
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
    purchaseLink: { href: 'path/to/purchase?plan_id=premium-plan-id' },
  };

  const rootUrl = 'https://gitlab.com/';

  const defaultPropsData = { eligibleGroups, plansData, rootUrl };

  const closeMock = jest.fn();

  const groupNameErrorMessage = `can contain only letters, digits, emoji, '_', '.', dash, space, parenthesis. It must start with letter, digit, emoji or '_'`;

  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findGroupNameInput = () => wrapper.findByTestId('subscription-group-name');
  const findCreateNewGroupButton = () => wrapper.findByTestId('show-new-group-form-button');
  const findGroupUrl = () => wrapper.findByTestId('group-url');
  const findErrorAlert = () => wrapper.findComponent(GlAlert);
  const findHeader = () => wrapper.find('h2');
  const findGroupDescription = () => wrapper.findByTestId('group-description');
  const findGroupIdValidationMessage = () =>
    wrapper.findByText('Select a group for your subscription.');
  const findGroupNameValidationMessage = () =>
    wrapper.findByText('Enter a descriptive name for your group.');

  const showNewGroupForm = async () => {
    findCreateNewGroupButton().vm.$emit('click');
    await nextTick();
  };

  const changeGroupName = async (groupName) => {
    await findGroupNameInput().setValue(groupName);
    await nextTick();
  };

  const selectGroup = async (groupId) => {
    findCollapsibleListbox().vm.$emit('select', groupId);
    await nextTick();
  };

  const submitForm = async () => {
    wrapper.findComponent(GlForm).trigger('submit');
    await nextTick();
  };

  const mockAvailableGroupPathResponse = () => {
    getGroupPathAvailability.mockResolvedValueOnce({
      data: { exists: false, suggests: [] },
    });
  };

  const mockUnavailableGroupPathResponse = (urlSuggestions = []) => {
    getGroupPathAvailability.mockResolvedValueOnce({
      data: { exists: true, suggests: urlSuggestions },
    });
  };

  const mockUnsuccessfulGroupPathResponse = () => {
    getGroupPathAvailability.mockRejectedValueOnce({});
  };

  const createComponent = (propsData = {}) => {
    wrapper = mountExtended(Component, {
      attachTo: document.body,
      propsData: {
        ...defaultPropsData,
        ...propsData,
      },
      stubs: {
        GlCollapsibleListbox: stubComponent(GlCollapsibleListbox, {
          template: `<div><slot name="footer"></slot></div>`,
          methods: {
            close: closeMock,
          },
        }),
      },
    });
  };

  describe('title', () => {
    beforeEach(() => {
      createComponent();
    });

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
    beforeEach(() => {
      createComponent();
    });

    it('renders collapsible list box with correct options', () => {
      const expectedResult = eligibleGroups.map(({ id, name }) => ({ value: id, text: name }));

      expect(findCollapsibleListbox().props().items).toEqual(expectedResult);
    });

    it('renders collapsible list box with correct variant', () => {
      expect(findCollapsibleListbox().props('variant')).toBe('default');
    });

    it('does not show validation message on initial render', () => {
      expect(findGroupIdValidationMessage().exists()).toBe(false);
    });

    it('shows appropriate toggle text on initial render', () => {
      expect(findCollapsibleListbox().props().toggleText).toBe('Select a group');
    });

    it('does not show group name input on initial render', () => {
      expect(findGroupNameInput().exists()).toBe(false);
    });

    it('does not show group description', () => {
      expect(findGroupDescription().exists()).toBe(false);
    });

    it('shows validation message when no group is selected', async () => {
      await submitForm();

      expect(findGroupIdValidationMessage().exists()).toBe(true);
      expect(findCollapsibleListbox().props('variant')).toBe('danger');
    });

    it('does not redirect when no group is selected', async () => {
      await submitForm();

      expect(visitUrl).not.toHaveBeenCalled();
    });

    it('shows appropriate toggle text when a group is selected', async () => {
      const selectedGroup = eligibleGroups[2];

      await selectGroup(selectedGroup.id);

      expect(findCollapsibleListbox().props().toggleText).toBe(selectedGroup.name);
    });

    it('redirects to purchase flow when a valid group is selected', async () => {
      const selectedGroupId = eligibleGroups[2].id;
      const expectedUrl = `${plansData.purchaseLink.href}&gl_namespace_id=${selectedGroupId}`;

      await selectGroup(selectedGroupId);
      await submitForm();

      expect(visitUrl).toHaveBeenCalledWith(expectedUrl);
    });

    it('does not call create group API when continuing with existing group', async () => {
      await selectGroup(eligibleGroups[2].id);
      await submitForm();

      expect(subscriptionsCreateGroup).not.toHaveBeenCalled();
    });
  });

  describe('when purchase link is missing', () => {
    it('reports an error when no purchase link URL is provided', async () => {
      const plansDataProp = { ...plansData, purchaseLink: null };
      const error = `Missing purchase link for plan ${JSON.stringify(plansDataProp)}`;

      createComponent({ plansData: plansDataProp });

      await selectGroup(eligibleGroups[2].id);
      await submitForm();

      expect(visitUrl).not.toHaveBeenCalled();
      expect(Sentry.captureException).toHaveBeenCalledWith(error, {
        tags: { vue_component: 'SubscriptionGroupSelector' },
      });
    });
  });

  describe('new group creation', () => {
    describe('when choosing to create a new group', () => {
      beforeEach(async () => {
        createComponent();
        await showNewGroupForm();
      });

      it('shows group name input', () => {
        expect(findGroupNameInput().exists()).toBe(true);
      });

      it('shows appropriate toggle text', () => {
        expect(findCollapsibleListbox().props().toggleText).toBe('Create new group');
      });

      it('does not show validation message', () => {
        expect(findGroupNameValidationMessage().exists()).toBe(false);
      });

      it('shows default group URL', () => {
        expect(findGroupUrl().text()).toBe(`${rootUrl}{group}`);
      });

      it('closes the collapsible list box', () => {
        expect(closeMock).toHaveBeenCalled();
      });
    });

    describe('when choosing to create a new group after selecting an existing group', () => {
      beforeEach(async () => {
        createComponent();
        await selectGroup(eligibleGroups[2].id);
        await showNewGroupForm();
      });

      it('shows appropriate toggle text', () => {
        expect(findCollapsibleListbox().props().toggleText).toBe('Create new group');
      });

      it('shows group name input', () => {
        expect(findGroupNameInput().exists()).toBe(true);
      });
    });

    describe('when no group name is provided', () => {
      beforeEach(async () => {
        createComponent();
        await showNewGroupForm();
        await submitForm();
      });

      it('shows validation message', () => {
        expect(findGroupNameValidationMessage().exists()).toBe(true);
      });

      it('does not redirect', () => {
        expect(visitUrl).not.toHaveBeenCalled();
      });

      it('does not show validation message for group selection', () => {
        expect(findGroupIdValidationMessage().exists()).toBe(false);
      });
    });

    describe('on group name input', () => {
      describe('when group path is available', () => {
        beforeEach(async () => {
          mockAvailableGroupPathResponse();
          createComponent();
          await showNewGroupForm();
          await changeGroupName('test group');
        });

        it('calls group availability API', () => {
          expect(getGroupPathAvailability).toHaveBeenCalledWith('test-group', undefined, {
            signal: expect.any(AbortSignal),
          });
        });

        it('shows path where group will be created', () => {
          expect(findGroupUrl().text()).toBe(`${rootUrl}test-group`);
        });
      });

      describe('when group path is not available', () => {
        beforeEach(async () => {
          mockUnavailableGroupPathResponse(['unique-path']);
          createComponent();
          await showNewGroupForm();
          await changeGroupName('test group');
        });

        it('shows unique path where group will be created', () => {
          expect(findGroupUrl().text()).toBe(`${rootUrl}unique-path`);
        });
      });

      describe('when no path suggestions are available', () => {
        beforeEach(async () => {
          mockUnavailableGroupPathResponse();
          createComponent();
          await showNewGroupForm();
          await changeGroupName('test group');
        });

        it('shows an error message', () => {
          expect(findErrorAlert().text()).toBe(
            'Unable to suggest a path. Please refresh and try again.',
          );
        });
      });

      describe('when path availability API call fails', () => {
        beforeEach(async () => {
          mockUnsuccessfulGroupPathResponse();
          createComponent();
          await showNewGroupForm();
          await changeGroupName('test group');
        });

        it('shows an error message', () => {
          expect(findErrorAlert().text()).toBe(
            'An error occurred while checking group path. Please refresh and try again.',
          );
        });
      });

      describe('when multiple API calls are in progress', () => {
        it('aborts the first API call and resolves the second API call', async () => {
          getGroupPathAvailability.mockRejectedValueOnce({ __CANCEL__: true });
          mockUnavailableGroupPathResponse(['test-group']);

          const abortSpy = jest.spyOn(AbortController.prototype, 'abort');

          createComponent();

          await showNewGroupForm();
          await changeGroupName('test');
          await changeGroupName('test group');

          expect(findErrorAlert().exists()).toBe(false);
          expect(findGroupUrl().text()).toBe(`${rootUrl}test-group`);
          expect(abortSpy).toHaveBeenCalled();
        });
      });
    });

    describe('when creating a new group', () => {
      beforeEach(async () => {
        mockUnavailableGroupPathResponse(['unique-path']);
        createComponent();
        await showNewGroupForm();
        await changeGroupName('test group');
      });
      describe('when group creation is successful', () => {
        beforeEach(async () => {
          subscriptionsCreateGroup.mockResolvedValueOnce({ data: { id: 123 } });

          await submitForm();
          await waitForPromises();
        });

        it('calls create group API with appropriate params', () => {
          expect(subscriptionsCreateGroup).toHaveBeenCalledWith({
            name: 'test group',
            path: 'unique-path',
          });
        });

        it('redirects to purchase page', () => {
          expect(visitUrl).toHaveBeenCalledWith(
            `${plansData.purchaseLink.href}&gl_namespace_id=123`,
          );
        });
      });

      describe('when API response has no group id', () => {
        beforeEach(async () => {
          subscriptionsCreateGroup.mockResolvedValueOnce({ data: {} });

          await submitForm();
          await waitForPromises();
        });

        it('does not redirect to purchase page', () => {
          expect(visitUrl).not.toHaveBeenCalled();
        });

        it('shows an error message', () => {
          expect(findErrorAlert().text()).toBe(
            `An error occurred while creating the group. Please try again.`,
          );
        });
      });

      describe('when group name is invalid', () => {
        beforeEach(async () => {
          subscriptionsCreateGroup.mockRejectedValueOnce({
            response: {
              data: {
                errors: {
                  name: [groupNameErrorMessage],
                },
              },
            },
          });

          await submitForm();
          await waitForPromises();
        });

        it('does not redirect to purchase page', () => {
          expect(visitUrl).not.toHaveBeenCalled();
        });

        it('shows an error message', () => {
          expect(findErrorAlert().text()).toBe(`Group name ${groupNameErrorMessage}`);
        });
      });

      describe('when group creation is unsuccessful', () => {
        beforeEach(async () => {
          subscriptionsCreateGroup.mockRejectedValueOnce(new Error('Error message'));

          await submitForm();
          await waitForPromises();
        });

        it('does not redirect to purchase page', () => {
          expect(visitUrl).not.toHaveBeenCalled();
        });

        it('shows an error message', () => {
          expect(findErrorAlert().text()).toBe(
            `An error occurred while creating the group. Please try again.`,
          );
        });
      });
    });
  });

  describe('when no eligible groups exist', () => {
    beforeEach(() => {
      createComponent({ eligibleGroups: [] });
    });

    it('shows group name input', () => {
      expect(findGroupNameInput().exists()).toBe(true);
    });

    it('does not show group selection input', () => {
      expect(findCollapsibleListbox().exists()).toBe(false);
    });

    it('does not show the accordion when no eligible groups exist', () => {
      expect(findAccordion().exists()).toBe(false);
    });

    it('shows group description', () => {
      expect(findGroupDescription().exists()).toBe(true);
    });
  });

  describe('accordion', () => {
    beforeEach(() => {
      createComponent();
    });

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
