import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon, GlLabel, GlTabs } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { EDIT_ROUTE_NAME, DETAILS_ROUTE_NAME, AUDIT_LOG_ROUTE_NAME } from 'ee/ci/secrets/constants';
import SecretTabs from 'ee/ci/secrets/components/secret_details/secret_tabs.vue';
import getSecretDetailsQuery from 'ee/ci/secrets/graphql/queries/client/get_secret_details.query.graphql';
import { mockSecretId, mockSecret, mockProjectSecretQueryResponse } from '../../mock_data';

Vue.use(VueApollo);

describe('SecretTabs component', () => {
  let wrapper;
  let mockApollo;
  const mockSecretDetails = jest.fn();

  const mockRouter = {
    push: jest.fn(),
  };
  const defaultProps = {
    fullPath: '/path/to/project',
    secretId: mockSecretId,
  };

  const findCreatedAtText = () => wrapper.findByTestId('secret-created-at').text();
  const findEditButton = () => wrapper.findByTestId('secret-edit-button');
  const findEnvLabel = () => wrapper.findComponent(GlLabel);
  const findDeleteButton = () => wrapper.findByTestId('secret-delete-button');
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findTitle = () => wrapper.find('h1').text();
  const findRevokeButton = () => wrapper.findByTestId('secret-revoke-button');
  const findTabs = () => wrapper.findComponent(GlTabs);

  const createComponent = (routeName = DETAILS_ROUTE_NAME) => {
    const handlers = [[getSecretDetailsQuery, mockSecretDetails]];
    mockApollo = createMockApollo(handlers);

    wrapper = shallowMountExtended(SecretTabs, {
      apolloProvider: mockApollo,
      propsData: {
        ...defaultProps,
        routeName,
      },
      stubs: {
        RouterView: true,
      },
      mocks: {
        $router: mockRouter,
        $route: { name: routeName },
      },
    });
  };

  beforeEach(() => {
    mockSecretDetails.mockResolvedValue(mockProjectSecretQueryResponse());
  });

  describe('while fetching the secret', () => {
    it('renders loading icon', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('when secret is fetched', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders header information', () => {
      const localizedCreatedAt = localeDateFormat.asDateTimeFull.format(mockSecret().createdAt);
      expect(findTitle()).toBe('APP_PWD');
      expect(findEnvLabel().attributes('title')).toBe('env::staging');
      expect(findCreatedAtText()).toBe(`Created on ${localizedCreatedAt}`);
    });

    it('renders action buttons', () => {
      expect(findEditButton().exists()).toBe(true);
      expect(findRevokeButton().exists()).toBe(true);
      expect(findDeleteButton().exists()).toBe(true);
    });
  });

  describe('environment label', () => {
    it.each`
      environment         | label
      ${'*'}              | ${'env::all (default)'}
      ${'Not applicable'} | ${'env::not applicable'}
      ${'staging'}        | ${'env::staging'}
    `('renders $environment as $label', async ({ environment, label }) => {
      mockSecretDetails.mockResolvedValue(
        mockProjectSecretQueryResponse({ customSecret: { environment } }),
      );
      createComponent();
      await waitForPromises();

      expect(findEnvLabel().attributes('title')).toBe(label);
    });
  });

  describe.each`
    description                  | routeName               | tabIndex
    ${'details tab is active'}   | ${DETAILS_ROUTE_NAME}   | ${0}
    ${'audit log tab is active'} | ${AUDIT_LOG_ROUTE_NAME} | ${1}
  `(`when $description`, ({ routeName, tabIndex }) => {
    beforeEach(() => {
      createComponent(routeName);
      return waitForPromises();
    });

    it('shows a link to the edit secret page', () => {
      findEditButton().vm.$emit('click');
      expect(mockRouter.push).toHaveBeenCalledWith({
        name: EDIT_ROUTE_NAME,
        params: { id: defaultProps.secretId },
      });
    });

    it('highlights the correct tab', () => {
      expect(findTabs().props('value')).toBe(tabIndex);
    });
  });
});
