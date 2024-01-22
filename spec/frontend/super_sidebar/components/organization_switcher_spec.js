import { GlAvatar, GlDisclosureDropdown, GlLoadingIcon } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue from 'vue';

import { mountExtended } from 'helpers/vue_test_utils_helper';
import OrganizationSwitcher from '~/super_sidebar/components/organization_switcher.vue';
import {
  defaultOrganization as currentOrganization,
  organizations as nodes,
  pageInfo,
  pageInfoEmpty,
} from '~/organizations/mock_data';
import organizationsQuery from '~/organizations/shared/graphql/queries/organizations.query.graphql';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

describe('OrganizationSwitcher', () => {
  let wrapper;
  let mockApollo;

  const [, secondOrganization, thirdOrganization] = nodes;

  const organizations = {
    nodes,
    pageInfo,
  };

  const successHandler = jest.fn().mockResolvedValue({
    data: {
      currentUser: {
        id: 'gid://gitlab/User/1',
        organizations,
      },
    },
  });

  const createComponent = (handler = successHandler) => {
    mockApollo = createMockApollo([[organizationsQuery, handler]]);

    wrapper = mountExtended(OrganizationSwitcher, {
      apolloProvider: mockApollo,
    });
  };

  const findDropdownItemByIndex = (index) =>
    wrapper.findAllByTestId('disclosure-dropdown-item').at(index);
  const showDropdown = () => wrapper.findComponent(GlDisclosureDropdown).vm.$emit('shown');

  afterEach(() => {
    mockApollo = null;
  });

  it('renders disclosure dropdown with current organization selected', () => {
    createComponent();

    const toggleButton = wrapper.findByTestId('toggle-button');
    const dropdownItem = findDropdownItemByIndex(0);

    expect(toggleButton.text()).toContain(currentOrganization.name);
    expect(toggleButton.findComponent(GlAvatar).props()).toMatchObject({
      src: currentOrganization.avatar_url,
      entityId: currentOrganization.id,
      entityName: currentOrganization.name,
    });
    expect(dropdownItem.text()).toContain(currentOrganization.name);
    expect(dropdownItem.findComponent(GlAvatar).props()).toMatchObject({
      src: currentOrganization.avatar_url,
      entityId: currentOrganization.id,
      entityName: currentOrganization.name,
    });
  });

  it('does not call GraphQL query', () => {
    createComponent();

    expect(successHandler).not.toHaveBeenCalled();
  });

  describe('when dropdown is shown', () => {
    it('calls GraphQL query and renders organizations that are available to switch to', async () => {
      createComponent();
      showDropdown();

      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);

      await waitForPromises();

      expect(findDropdownItemByIndex(1).text()).toContain(secondOrganization.name);
      expect(findDropdownItemByIndex(1).element.firstChild.getAttribute('href')).toBe(
        secondOrganization.webUrl,
      );
      expect(findDropdownItemByIndex(1).findComponent(GlAvatar).props()).toMatchObject({
        src: secondOrganization.avatarUrl,
        entityId: getIdFromGraphQLId(secondOrganization.id),
        entityName: secondOrganization.name,
      });

      expect(findDropdownItemByIndex(2).text()).toContain(thirdOrganization.name);
      expect(findDropdownItemByIndex(2).element.firstChild.getAttribute('href')).toBe(
        thirdOrganization.webUrl,
      );
      expect(findDropdownItemByIndex(2).findComponent(GlAvatar).props()).toMatchObject({
        src: thirdOrganization.avatarUrl,
        entityId: getIdFromGraphQLId(thirdOrganization.id),
        entityName: thirdOrganization.name,
      });
    });

    describe('when there are no organizations to switch to', () => {
      beforeEach(async () => {
        createComponent(
          jest.fn().mockResolvedValue({
            data: {
              currentUser: {
                id: 'gid://gitlab/User/1',
                organizations: {
                  nodes: [],
                  pageInfo: pageInfoEmpty,
                },
              },
            },
          }),
        );
        showDropdown();
        await waitForPromises();
      });

      it('renders empty message', () => {
        expect(findDropdownItemByIndex(1).text()).toBe('No organizations available to switch to.');
      });
    });

    describe('when there is an error fetching organizations', () => {
      beforeEach(async () => {
        createComponent(jest.fn().mockRejectedValue());
        showDropdown();
        await waitForPromises();
      });

      it('renders empty message', () => {
        expect(findDropdownItemByIndex(1).text()).toBe('No organizations available to switch to.');
      });
    });
  });
});
