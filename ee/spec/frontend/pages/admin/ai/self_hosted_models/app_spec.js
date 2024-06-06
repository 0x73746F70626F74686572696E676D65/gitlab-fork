import { mount } from '@vue/test-utils';
import { GlEmptyState } from '@gitlab/ui';
import CustomModelsApp from 'ee/pages/admin/ai/self_hosted_models/app.vue';
import { mockCustomModel } from './mock_data';

describe('CustomModelsApp', () => {
  let wrapper;

  const createComponent = ({ props }) => {
    wrapper = mount(CustomModelsApp, {
      propsData: {
        ...props,
      },
    });
  };

  describe('when there are custom models', () => {
    beforeEach(() => {
      createComponent({ props: { models: [mockCustomModel] } });
    });

    /**
     * TODO: Add testing for custom model entries
     * This will be implemented in https://gitlab.com/gitlab-org/gitlab/-/issues/463134
     *
     * it('renders custom model entries', () => {});
     */

    it('does not render custom models empty state', () => {
      expect(wrapper.findComponent(GlEmptyState).exists()).toBe(false);
    });
  });

  describe('when there are no custom models', () => {
    beforeEach(() => {
      createComponent({ props: { models: [] } });
    });

    it('renders custom models empty state', () => {
      expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
    });
  });
});
