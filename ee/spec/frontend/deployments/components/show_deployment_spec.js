import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { shallowMount } from '@vue/test-utils';
import mockDeploymentFixture from 'test_fixtures/ee/graphql/deployments/graphql/queries/deployment.query.graphql.json';
import mockEnvironmentFixture from 'test_fixtures/graphql/deployments/graphql/queries/environment.query.graphql.json';
import ShowDeployment from '~/deployments/components/show_deployment.vue';
import deploymentQuery from '~/deployments/graphql/queries/deployment.query.graphql';
import environmentQuery from '~/deployments/graphql/queries/environment.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import DeploymentTimeline from 'ee/deployments/components/deployment_timeline.vue';
import DeploymentApprovals from 'ee/deployments/components/deployment_approvals.vue';
import ApprovalsEmptyState from 'ee_else_ce/deployments/components/approvals_empty_state.vue';

Vue.use(VueApollo);

const { deployment } = mockDeploymentFixture.data.project;
const PROJECT_PATH = 'group/project';
const ENVIRONMENT_NAME = mockEnvironmentFixture.data.project.environment.name;
const DEPLOYMENT_IID = deployment.iid;
const GRAPHQL_ETAG_KEY = 'project/environments';
const PROTECTED_ENVIRONMENTS_SETTINGS_PATH = '/settings/ci_cd#js-protected-environments-settings';

describe('~/deployments/components/show_deployment.vue', () => {
  let wrapper;
  let mockApollo;
  let deploymentQueryResponse;
  let environmentQueryResponse;

  beforeEach(() => {
    deploymentQueryResponse = jest.fn();
    environmentQueryResponse = jest.fn();
  });

  const createComponent = () => {
    mockApollo = createMockApollo([
      [deploymentQuery, deploymentQueryResponse],
      [environmentQuery, environmentQueryResponse],
    ]);
    wrapper = shallowMount(ShowDeployment, {
      apolloProvider: mockApollo,
      provide: {
        projectPath: PROJECT_PATH,
        environmentName: ENVIRONMENT_NAME,
        deploymentIid: DEPLOYMENT_IID,
        graphqlEtagKey: GRAPHQL_ETAG_KEY,
        protectedEnvironmentsAvailable: true,
        protectedEnvironmentsSettingsPath: PROTECTED_ENVIRONMENTS_SETTINGS_PATH,
      },
    });
    return waitForPromises();
  };

  beforeEach(() => {
    deploymentQueryResponse.mockResolvedValue(mockDeploymentFixture);
    environmentQueryResponse.mockResolvedValue(mockEnvironmentFixture);
    return createComponent();
  });

  it('shows the deployment approval table', () => {
    expect(wrapper.findComponent(DeploymentApprovals).props()).toEqual({
      approvalSummary: deployment.approvalSummary,
      deployment,
    });
  });

  it('shows the deployment approvals timeline', () => {
    expect(wrapper.findComponent(DeploymentTimeline).props()).toEqual({
      approvalSummary: deployment.approvalSummary,
    });
  });

  it('shows the approvals empty state', () => {
    expect(wrapper.findComponent(ApprovalsEmptyState).props('approvalSummary')).toEqual(
      mockDeploymentFixture.data.project.deployment.approvalSummary,
    );
  });

  it('refetches the deployment on approval change', async () => {
    deploymentQueryResponse.mockClear();
    wrapper.findComponent(DeploymentApprovals).vm.$emit('change');
    await waitForPromises();

    expect(deploymentQueryResponse).toHaveBeenCalled();
  });
});
