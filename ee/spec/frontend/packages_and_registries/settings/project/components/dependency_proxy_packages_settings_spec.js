import { GlAlert, GlSkeletonLoader } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import DependencyProxyPackagesSettings from 'ee_component/packages_and_registries/settings/project/components/dependency_proxy_packages_settings.vue';
import DependencyProxyPackagesSettingsForm from 'ee_component/packages_and_registries/settings/project/components/dependency_proxy_packages_settings_form.vue';
import dependencyProxyPackagesSettingsQuery from 'ee_component/packages_and_registries/settings/project/graphql/queries/get_dependency_proxy_packages_settings.query.graphql';
import SettingsBlock from '~/packages_and_registries/shared/components/settings_block.vue';

import {
  dependencyProxyPackagesSettingsPayload,
  dependencyProxyPackagesSettingsData,
} from '../mock_data';

Vue.use(VueApollo);

describe('Dependency proxy packages project settings', () => {
  let wrapper;
  let fakeApollo;

  const defaultProvidedValues = {
    projectPath: 'path',
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findFormComponent = () => wrapper.findComponent(DependencyProxyPackagesSettingsForm);
  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findTitle = () => wrapper.findByTestId('title');
  const findDescription = () => wrapper.findByTestId('description');
  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);

  const mountComponent = (provide = defaultProvidedValues, config) => {
    wrapper = shallowMountExtended(DependencyProxyPackagesSettings, {
      stubs: {
        SettingsBlock,
      },
      provide,
      ...config,
    });
  };

  const mountComponentWithApollo = ({ provide = defaultProvidedValues, resolver } = {}) => {
    const requestHandlers = [[dependencyProxyPackagesSettingsQuery, resolver]];

    fakeApollo = createMockApollo(requestHandlers);
    mountComponent(provide, {
      apolloProvider: fakeApollo,
    });
  };

  afterEach(() => {
    fakeApollo = null;
  });

  it('renders settings block component', () => {
    mountComponentWithApollo();

    expect(findSettingsBlock().exists()).toBe(true);
  });

  it('has the correct header text and description', () => {
    mountComponentWithApollo();

    expect(findTitle().text()).toBe('Dependency Proxy');
    expect(findDescription().text()).toBe(
      'Enable the Dependency Proxy for packages, and configure connection settings for external registries.',
    );
    expect(findLoader().exists()).toBe(true);
  });

  it('renders the setting form', async () => {
    mountComponentWithApollo({
      resolver: jest.fn().mockResolvedValue(dependencyProxyPackagesSettingsPayload()),
    });
    await waitForPromises();

    expect(findLoader().exists()).toBe(false);
    expect(findFormComponent().props('data')).toEqual(dependencyProxyPackagesSettingsData);
  });

  describe('fetchSettingsError', () => {
    beforeEach(async () => {
      mountComponentWithApollo({
        resolver: jest.fn().mockRejectedValue(new Error('GraphQL error')),
      });
      await waitForPromises();
    });

    it('the form is hidden', () => {
      expect(findFormComponent().exists()).toBe(false);
    });

    it('shows an alert', () => {
      expect(findAlert().html()).toContain(
        'Something went wrong while fetching the dependency proxy settings.',
      );
    });
  });
});
