import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { createMockSubscription as createMockApolloSubscription } from 'mock-apollo-client';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ApprovalSummary from 'ee/merge_requests/components/reviewers/approval_summary.vue';
import approvalSummaryQuery from 'ee/merge_requests/queries/approval_summary.query.graphql';
import approvalSummarySubscription from 'ee/merge_requests/queries/approval_summary.subscription.graphql';

Vue.use(VueApollo);

const mockData = ({ approvalsRequired = 1, approvalsLeft = 1, approvedBy = [] } = {}) => ({
  data: {
    project: {
      id: 1,
      mergeRequest: {
        id: 1,
        approvalsLeft,
        approvalsRequired,
        approvedBy: {
          nodes: approvedBy,
        },
        approvalState: {
          rules: [
            {
              id: 1,
              approved: false,
              approvalsRequired,
              name: 'Frontend',
              type: 'CODE_OWNER',
            },
          ],
        },
      },
    },
  },
});

describe('Reviewers drawer approval summary component', () => {
  let wrapper;
  let apolloProvider;
  let mockedSubscription;

  const createComponent = ({
    multipleApprovalRulesAvailable = true,
    resolver = jest.fn().mockResolvedValue(mockData()),
  } = {}) => {
    mockedSubscription = createMockApolloSubscription();
    apolloProvider = createMockApollo([[approvalSummaryQuery, resolver]]);

    apolloProvider.defaultClient.setRequestHandler(
      approvalSummarySubscription,
      () => mockedSubscription,
    );

    wrapper = shallowMount(ApprovalSummary, {
      apolloProvider,
      provide: {
        projectPath: 'project-path',
        issuableId: '1',
        issuableIid: '1',
        multipleApprovalRulesAvailable,
      },
    });
  };

  it('renders loading skeleton', () => {
    createComponent();

    expect(wrapper.classes()).toContain('gl-animate-skeleton-loader');
  });

  describe('when approval is required', () => {
    it('renders approval summary', async () => {
      createComponent();

      await waitForPromises();

      expect(wrapper.text()).toBe('Requires 1 approval from Code Owners.');
    });
  });

  describe('when approval is optional', () => {
    it('renders optional approval summary', async () => {
      createComponent({
        resolver: jest.fn().mockResolvedValue(mockData({ approvalsRequired: 0 })),
      });

      await waitForPromises();

      expect(wrapper.text()).toBe('Approval is optional');
    });
  });

  it('updates text when subscription updates', async () => {
    createComponent();

    await waitForPromises();

    mockedSubscription.next({
      data: {
        mergeRequestApprovalStateUpdated: mockData({
          approvalsLeft: 0,
          approvalsRequired: 0,
          approvedBy: [{ id: 1 }],
        }).data.project.mergeRequest,
      },
    });

    await waitForPromises();

    expect(wrapper.text()).toBe('Requires 0 approvals from Code Owners.');
  });

  describe('when multipleApprovalRulesAvailable is false', () => {
    it('renders approval summary', async () => {
      createComponent({ multipleApprovalRulesAvailable: false });

      await waitForPromises();

      expect(wrapper.text()).toBe('Requires 1 approval from eligible users.');
    });
  });
});
