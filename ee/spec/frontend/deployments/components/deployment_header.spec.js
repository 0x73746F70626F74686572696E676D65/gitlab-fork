import { GlBadge } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import mockDeploymentFixture from 'test_fixtures/ee/graphql/deployments/graphql/queries/deployment.query.graphql.json';
import mockEnvironmentFixture from 'test_fixtures/graphql/deployments/graphql/queries/environment.query.graphql.json';
import DeploymentHeader from '~/deployments/components/deployment_header.vue';

const {
  data: {
    project: { deployment },
  },
} = mockDeploymentFixture;
const {
  data: {
    project: { environment },
  },
} = mockEnvironmentFixture;

describe('~/deployments/components/deployment_header.vue', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMount(DeploymentHeader, {
      propsData: {
        deployment,
        environment,
        loading: false,
        ...propsData,
      },
    });
  };

  const findNeedsApprovalBadge = () => wrapper.findComponent(GlBadge);

  it('shows a badge when the deployment needs approval', () => {
    createComponent({
      propsData: {
        deployment: {
          ...deployment,
          status: 'RUNNING',
          approvalSummary: { status: 'PENDING_APPROVAL' },
        },
      },
    });

    expect(findNeedsApprovalBadge().text()).toBe('Needs Approval');
  });

  it('hides the  badge when the deployment does not need approval', () => {
    createComponent({
      propsData: {
        deployment: {
          ...deployment,
          status: 'RUNNING',
          approvalSummary: { status: 'APPROVED' },
        },
      },
    });

    expect(findNeedsApprovalBadge().exists()).toBe(false);
  });

  it('hides the  badge when the deployment is finished', () => {
    createComponent({
      propsData: {
        deployment: {
          ...deployment,
          status: 'SUCCESS',
          approvalSummary: { status: 'PENDING_APPROVAL' },
        },
      },
    });

    expect(findNeedsApprovalBadge().exists()).toBe(false);
  });
});
