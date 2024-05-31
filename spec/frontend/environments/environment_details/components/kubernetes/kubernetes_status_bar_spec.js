import { GlLoadingIcon, GlPopover, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import KubernetesStatusBar from '~/environments/environment_details/components/kubernetes/kubernetes_status_bar.vue';
import KubernetesConnectionStatus from '~/environments/environment_details/components/kubernetes/kubernetes_connection_status.vue';
import {
  CLUSTER_HEALTH_SUCCESS,
  CLUSTER_HEALTH_ERROR,
  CLUSTER_STATUS_HEALTHY_TEXT,
  CLUSTER_STATUS_UNHEALTHY_TEXT,
  SYNC_STATUS_BADGES,
} from '~/environments/constants';
import {
  connectionStatus,
  k8sResourceType,
} from '~/environments/graphql/resolvers/kubernetes/constants';
import { stubComponent } from 'helpers/stub_component';
import { mockKasTunnelUrl } from '../../../mock_data';
import { kubernetesNamespace } from '../../../graphql/mock_data';

const configuration = {
  basePath: mockKasTunnelUrl.replace(/\/$/, ''),
  baseOptions: {
    headers: { 'GitLab-Agent-Id': '1' },
    withCredentials: true,
  },
};
const environmentName = 'environment_name';
const kustomizationResourcePath =
  'kustomize.toolkit.fluxcd.io/v1/namespaces/my-namespace/kustomizations/app';

describe('~/environments/environment_details/components/kubernetes/kubernetes_status_bar.vue', () => {
  let wrapper;

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findHealthBadge = () => wrapper.findByTestId('health-badge');
  const findSyncBadge = () => wrapper.findByTestId('sync-badge');
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findDashboardConnectionStatus = () => wrapper.findByTestId('dashboard-status-badge');
  const findFluxConnectionStatusBadge = () => wrapper.findByTestId('flux-status-badge');
  const findFluxConnectionStatus = () => wrapper.findByTestId('flux-connection-status');

  const createWrapper = ({
    clusterHealthStatus = '',
    fluxResourcePath = '',
    fluxResourceStatus = [],
    fluxApiError = '',
    namespace = kubernetesNamespace,
    resourceType = k8sResourceType.k8sPods,
    connectionStatusValue = connectionStatus.connected,
  } = {}) => {
    wrapper = shallowMountExtended(KubernetesStatusBar, {
      propsData: {
        clusterHealthStatus,
        configuration,
        environmentName,
        fluxResourcePath,
        namespace,
        resourceType,
        fluxResourceStatus,
        fluxApiError,
      },
      stubs: {
        GlSprintf,
        KubernetesConnectionStatus: stubComponent(KubernetesConnectionStatus, {
          template: `<div><slot  :connection-props="{ connectionStatus: '${connectionStatusValue}', reconnect: '' }"></slot></div>`,
        }),
      },
    });
  };

  describe('connection status', () => {
    describe('when fluxResourcePath is not provided', () => {
      beforeEach(() => {
        createWrapper();
      });

      it("doesn't render flux status component", () => {
        expect(findFluxConnectionStatusBadge().exists()).toBe(false);
      });
    });

    describe('when fluxResourcePath is provided', () => {
      it('passes correct props to connection status component', () => {
        createWrapper({ fluxResourcePath: kustomizationResourcePath });

        const dashboardConnectionStatus = findDashboardConnectionStatus();
        expect(dashboardConnectionStatus.props('configuration')).toBe(configuration);
        expect(dashboardConnectionStatus.props('namespace')).toBe(kubernetesNamespace);
        expect(dashboardConnectionStatus.props('resourceTypeParam')).toEqual({
          resourceType: k8sResourceType.k8sPods,
          connectionParams: null,
        });
      });

      it('passes correct props to flux connection status component', () => {
        createWrapper({ fluxResourcePath: kustomizationResourcePath });

        const fluxConnectionStatus = findFluxConnectionStatus();
        expect(fluxConnectionStatus.props('configuration')).toBe(configuration);
        expect(fluxConnectionStatus.props('namespace')).toBe(kubernetesNamespace);
        expect(fluxConnectionStatus.props('resourceTypeParam')).toEqual({
          resourceType: k8sResourceType.fluxKustomizations,
          connectionParams: {
            fluxResourcePath: kustomizationResourcePath,
          },
        });
      });

      it('handles errors from connection status component', () => {
        createWrapper({ fluxResourcePath: kustomizationResourcePath });

        const dashboardConnectionStatus = findDashboardConnectionStatus();
        const connectionStatusError = new Error('connection status error');
        dashboardConnectionStatus.vm.$emit('error', connectionStatusError);

        expect(wrapper.emitted('error')).toEqual([[connectionStatusError]]);
      });

      it.each([
        [connectionStatus.connected, 'not shown', false],
        [connectionStatus.connecting, 'shown', true],
        [connectionStatus.disconnected, 'shown', true],
      ])(
        'when connectionStatus is %s flux connection status badge is %s',
        (status, condition, exists) => {
          createWrapper({
            fluxResourcePath: kustomizationResourcePath,
            connectionStatusValue: status,
          });

          expect(findFluxConnectionStatusBadge().exists()).toBe(exists);
        },
      );
    });
  });

  describe('health badge', () => {
    it('shows loading icon when cluster health is not present', () => {
      createWrapper();

      expect(findLoadingIcon().exists()).toBe(true);
    });

    it.each([
      [CLUSTER_HEALTH_SUCCESS, 'success', 'status-success', CLUSTER_STATUS_HEALTHY_TEXT],
      [CLUSTER_HEALTH_ERROR, 'danger', 'status-alert', CLUSTER_STATUS_UNHEALTHY_TEXT],
    ])(
      'when clusterHealthStatus is %s shows health badge with variant %s, icon %s and text %s',
      (status, variant, icon, text) => {
        createWrapper({ clusterHealthStatus: status });

        expect(findLoadingIcon().exists()).toBe(false);
        expect(findHealthBadge().props()).toMatchObject({ variant, icon });
        expect(findHealthBadge().text()).toBe(text);
      },
    );
  });

  describe('sync badge', () => {
    describe('when no flux resource path is provided', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('renders sync status as Unavailable', () => {
        expect(findSyncBadge().text()).toBe('Unavailable');
      });
    });

    describe('when flux status data is provided', () => {
      const message = 'Message from Flux';

      it.each`
        status       | type             | reason           | statusText       | statusPopover
        ${'True'}    | ${'Stalled'}     | ${''}            | ${'Stalled'}     | ${message}
        ${'True'}    | ${'Reconciling'} | ${''}            | ${'Reconciling'} | ${'Flux sync reconciling'}
        ${'Unknown'} | ${'Ready'}       | ${'Progressing'} | ${'Reconciling'} | ${message}
        ${'True'}    | ${'Ready'}       | ${''}            | ${'Reconciled'}  | ${'Flux sync reconciled successfully'}
        ${'False'}   | ${'Ready'}       | ${''}            | ${'Failed'}      | ${message}
        ${'Unknown'} | ${'Ready'}       | ${''}            | ${'Unknown'}     | ${'Unable to detect state. How are states detected?'}
      `(
        'renders sync status as $statusText when status is $status, type is $type, and reason is $reason',
        ({ status, type, reason, statusText, statusPopover }) => {
          createWrapper({
            fluxResourceStatus: [
              {
                status,
                type,
                reason,
                message,
              },
            ],
          });

          expect(findSyncBadge().text()).toBe(statusText);
          expect(findPopover().text()).toBe(statusPopover);
        },
      );

      describe('when Flux API errored', () => {
        const fluxApiError = 'Error from the cluster_client API';

        beforeEach(() => {
          createWrapper({ fluxApiError });
        });

        it('renders sync badge as unavailable', () => {
          const badge = SYNC_STATUS_BADGES.unavailable;

          expect(findSyncBadge().text()).toBe(badge.text);
          expect(findSyncBadge().props()).toMatchObject({
            icon: badge.icon,
            variant: badge.variant,
          });
        });

        it('renders popover with an API error message', () => {
          expect(findPopover().text()).toBe(fluxApiError);
          expect(findPopover().props('title')).toBe('Flux sync status is unavailable');
        });
      });
    });
  });
});
