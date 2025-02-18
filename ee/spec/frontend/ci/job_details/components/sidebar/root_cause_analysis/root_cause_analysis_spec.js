import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlEmptyState, GlSkeletonLoader, GlExperimentBadge, GlDrawer } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RootCauseAnalysis from 'ee/ci/job_details/components/sidebar/root_cause_analysis/root_cause_analysis_app.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import Markdown from '~/vue_shared/components/markdown/non_gfm_markdown.vue';
import rootCauseMutation from 'ee/ci/job_details/components/sidebar/root_cause_analysis/graphql/root_cause.mutation.graphql';
import rootCauseQuery from 'ee/ci/job_details/components/sidebar/root_cause_analysis/graphql/root_cause.query.graphql';

describe('rootCauseAnalysis', () => {
  let wrapper;
  let mockApollo;

  const projectPath = 'project/path';

  const mockRootCauseQueryData = {
    data: {
      project: {
        id: '1',
        __typename: 'Project',
        job: {
          id: '123',
          __typename: 'CiJob',
          aiFailureAnalysis: 'This is a test failure analysis.',
        },
      },
    },
  };

  const mockRootCauseQueryDataEmpty = {
    data: {
      project: {
        id: '1',
        __typename: 'Project',
        job: {
          id: '123',
          __typename: 'CiJob',
          aiFailureAnalysis: null,
        },
      },
    },
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findActionButton = () => wrapper.findByTestId('root-cause-analysis-action-button');
  const findMarkdown = () => wrapper.findComponent(Markdown);
  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findAlert = () => wrapper.findComponent(GlAlert);

  const rootCauseQueryHandlerMock = jest.fn();
  const rootCauseMutationHandlerMock = jest.fn().mockResolvedValue({
    data: {
      aiAction: {
        clientMutationId: 'mutationId',
        errors: [],
        requestId: 'requestId',
      },
    },
  });

  const defaultProps = {
    isShown: true,
    jobId: 'gid://gitlab/Ci::Build/123',
    isJobLoading: false,
  };

  const createComponent = ({ props, rootCauseData } = { props: {} }) => {
    const propsData = { ...defaultProps, ...props };
    Vue.use(VueApollo);

    const handlers = [
      [
        rootCauseQuery,
        rootCauseQueryHandlerMock.mockResolvedValue(rootCauseData || mockRootCauseQueryDataEmpty),
      ],
      [rootCauseMutation, rootCauseMutationHandlerMock],
    ];

    mockApollo = createMockApollo(handlers);

    wrapper = shallowMountExtended(RootCauseAnalysis, {
      propsData,
      provide: { projectPath },
      apolloProvider: mockApollo,
      stubs: {
        GlEmptyState,
        GlDrawer,
      },
    });
  };

  const itHasLegalDisclaimer = () => {
    describe('legal disclaimer', () => {
      it('renders experiment badge', () => {
        expect(findExperimentBadge().exists()).toBe(true);
      });

      it('renders warning alert', () => {
        expect(findAlert().exists()).toBe(true);
        expect(findAlert().props()).toMatchObject({
          dismissible: false,
          variant: 'tip',
          showIcon: false,
        });
      });
    });
  };

  describe('when the data is not ready', () => {
    beforeEach(() => {
      createComponent();
    });

    itHasLegalDisclaimer();

    it('the empty state is shown', () => {
      const emptyState = findEmptyState();
      expect(emptyState.exists()).toBe(true);
    });

    it('markdown is not shown', () => {
      const markdown = findMarkdown();
      expect(markdown.exists()).toBe(false);
    });

    it('loader is not shown', () => {
      const loader = findLoader();
      expect(loader.exists()).toBe(false);
    });

    describe('when action button is clicked', () => {
      beforeEach(() => {
        const actionButton = findActionButton();
        actionButton.vm.$emit('click');
      });

      it('should show the loader', () => {
        const loader = findLoader();
        expect(loader.exists()).toBe(true);
      });

      it('should trigger the mutation', () => {
        expect(rootCauseMutationHandlerMock).toHaveBeenCalledWith({
          jobId: 'gid://gitlab/Ci::Build/123',
        });
      });
    });
  });

  describe('when the data is ready', () => {
    beforeEach(async () => {
      createComponent({ propsData: { isShown: true }, rootCauseData: mockRootCauseQueryData });
      await waitForPromises();
    });

    itHasLegalDisclaimer();

    it('the empty state is not shown', () => {
      const emptyState = findEmptyState();
      expect(emptyState.exists()).toBe(false);
    });

    it('markdown is shown', () => {
      const markdown = findMarkdown();
      expect(markdown.exists()).toBe(true);
      expect(markdown.props().markdown).toBe(
        mockRootCauseQueryData.data.project.job.aiFailureAnalysis,
      );
    });
  });
});
