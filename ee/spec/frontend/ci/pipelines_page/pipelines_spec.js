import MockAdapter from 'axios-mock-adapter';
import { shallowMount } from '@vue/test-utils';
import axios from '~/lib/utils/axios_utils';
import PipelinesComponent from '~/ci/pipelines_page/pipelines.vue';
import Store from '~/ci/pipeline_details/stores/pipelines_store';
import PipelineAccountVerificationAlert from 'ee/vue_shared/components/pipeline_account_verification_alert.vue';
import waitForPromises from 'helpers/wait_for_promises';

describe('Pipelines', () => {
  let wrapper;
  let mock;

  const createComponent = ({ identityVerificationRequired = false } = {}) => {
    wrapper = shallowMount(PipelinesComponent, {
      propsData: {
        store: new Store(),
        endpoint: 'some/endpoint',
        hasGitlabCi: true,
        canCreatePipeline: false,
        projectId: '1',
        params: {},
      },
      provide: { identityVerificationRequired, identityVerificationPath: '#' },
    });
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  // PipelineAccountVerificationAlert handles its own rendering, we just need to check that the component is mounted
  // regardless what the value of identityVerificationRequired is.
  it.each([true, false])(
    'shows pipeline account verification alert when identityVerificationRequired is %s',
    async (identityVerificationRequired) => {
      createComponent({ identityVerificationRequired });
      await waitForPromises();

      expect(wrapper.findComponent(PipelineAccountVerificationAlert).exists()).toBe(true);
    },
  );
});
