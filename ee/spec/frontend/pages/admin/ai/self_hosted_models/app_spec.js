import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { GlEmptyState, GlButton, GlSkeletonLoader } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import SelfHostedModelsApp from 'ee/pages/admin/ai/self_hosted_models/components/app.vue';
import getSelfHostedModelsQuery from 'ee/pages/admin/ai/self_hosted_models/queries/get_self_hosted_models.query.graphql';
import SelfHostedModelsTable from 'ee/pages/admin/ai/self_hosted_models/components/self_hosted_models_table.vue';
import { createAlert } from '~/alert';
import { mockAiSelfHostedModelsQueryResponse, mockSelfHostedModelsList } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('SelfHostedModelsApp', () => {
  let wrapper;

  const createComponent = ({
    apolloHandlers = [
      [getSelfHostedModelsQuery, jest.fn().mockResolvedValue(mockAiSelfHostedModelsQueryResponse)],
    ],
  } = {}) => {
    const mockApollo = createMockApollo([...apolloHandlers]);
    const basePath = '/admin/ai/self_hosted_models';
    const newSelfHostedModelPath = '/admin/ai/self_hosted_models/new';

    wrapper = shallowMount(SelfHostedModelsApp, {
      apolloProvider: mockApollo,
      propsData: {
        basePath,
        newSelfHostedModelPath,
      },
    });
  };

  const findSelfHostedModelsTable = () => wrapper.findComponent(SelfHostedModelsTable);
  const findLoader = () => wrapper.getComponent(GlSkeletonLoader);
  const findButton = () => wrapper.findComponent(GlButton);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);

  describe('when self-hosted models are loading', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders skeleton loader', () => {
      expect(findLoader().exists()).toBe(true);
    });
  });

  describe('when the API request is successful', () => {
    describe('when there are self-hosted models', () => {
      beforeEach(async () => {
        createComponent();

        await waitForPromises();
      });

      it('renders self-hosted models table component', () => {
        expect(findSelfHostedModelsTable().props('models')).toStrictEqual(mockSelfHostedModelsList);
      });

      it('renders button to create new self-hosted model', () => {
        const button = findButton();

        expect(button.text()).toBe('New model');
        expect(button.attributes('href')).toBe('/admin/ai/self_hosted_models/new');
      });
    });

    describe('when there are no self-hosted models', () => {
      beforeEach(async () => {
        const mockQueryResponse = jest.fn().mockResolvedValue({
          data: {
            aiSelfHostedModels: {
              nodes: [],
            },
          },
        });

        createComponent({
          apolloHandlers: [[getSelfHostedModelsQuery, mockQueryResponse]],
        });

        await waitForPromises();
      });

      it('renders self-hosted models empty state', () => {
        expect(findEmptyState().exists()).toBe(true);
      });
    });
  });

  describe('when the API request is unsuccessful', () => {
    const error = new Error();

    beforeEach(async () => {
      createComponent({
        apolloHandlers: [[getSelfHostedModelsQuery, jest.fn().mockRejectedValue(error)]],
      });

      await waitForPromises();
    });

    it('displays an error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while loading self-hosted models. Please try again.',
        error,
        captureError: true,
      });
    });
  });
});
