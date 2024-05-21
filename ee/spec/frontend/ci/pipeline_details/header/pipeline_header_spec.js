import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import PipelineHeader from '~/ci/pipeline_details/header/pipeline_header.vue';
import getPipelineDetailsQuery from '~/ci/pipeline_details/header/graphql/queries/get_pipeline_header_data.query.graphql';
import PipelineAccountVerificationAlert from 'ee/vue_shared/components/pipeline_account_verification_alert.vue';
import {
  pipelineHeaderFinishedComputeMinutes,
  pipelineHeaderRunning,
  pipelineHeaderSuccess,
} from '../mock_data';

Vue.use(VueApollo);

describe('Pipeline header', () => {
  let wrapper;

  const minutesHandler = jest.fn().mockResolvedValue(pipelineHeaderFinishedComputeMinutes);
  const successHandler = jest.fn().mockResolvedValue(pipelineHeaderSuccess);
  const runningHandler = jest.fn().mockResolvedValue(pipelineHeaderRunning);

  const findComputeMinutes = () => wrapper.findByTestId('compute-minutes');

  const defaultHandlers = [[getPipelineDetailsQuery, minutesHandler]];

  const defaultProvideOptions = {
    pipelineIid: 1,
    identityVerificationPath: '#',
    paths: {
      pipelinesPath: '/namespace/my-project/-/pipelines',
      fullProject: '/namespace/my-project',
    },
  };

  const defaultProps = {
    yamlErrors: 'errors',
    trigger: false,
  };

  const createMockApolloProvider = (handlers) => {
    return createMockApollo(handlers);
  };

  const createComponent = ({
    handlers = defaultHandlers,
    identityVerificationRequired = true,
  } = {}) => {
    wrapper = shallowMountExtended(PipelineHeader, {
      provide: { ...defaultProvideOptions, identityVerificationRequired },
      propsData: defaultProps,
      apolloProvider: createMockApolloProvider(handlers),
    });

    return waitForPromises();
  };

  // PipelineAccountVerificationAlert handles its own rendering, we just need to check that the component is
  // mounted regardless what the value of identityVerificationRequired is.
  it.each([true, false])(
    'shows pipeline account verification alert',
    async (identityVerificationRequired) => {
      await createComponent({ identityVerificationRequired });

      expect(wrapper.findComponent(PipelineAccountVerificationAlert).exists()).toBe(true);
    },
  );

  describe('finished pipeline', () => {
    it('displays compute minutes when not zero', async () => {
      await createComponent();

      expect(findComputeMinutes().text()).toBe('25');
    });

    it('does not display compute minutes when zero', async () => {
      await createComponent({ handlers: [[getPipelineDetailsQuery, successHandler]] });

      expect(findComputeMinutes().exists()).toBe(false);
    });
  });

  describe('running pipeline', () => {
    beforeEach(() => {
      return createComponent({ handlers: [[getPipelineDetailsQuery, runningHandler]] });
    });

    it('does not display compute minutes', () => {
      expect(findComputeMinutes().exists()).toBe(false);
    });
  });
});
