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

Vue.use(VueApollo);

const { deployment } = mockDeploymentFixture.data.project;
const PROJECT_PATH = 'group/project';
const ENVIRONMENT_NAME = mockEnvironmentFixture.data.project.environment.name;
const DEPLOYMENT_IID = deployment.iid;

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
});
